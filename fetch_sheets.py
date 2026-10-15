"""Скачивает исходные таблицы для ежедневной сборки дашборда.

Нужна переменная окружения GOOGLE_SA_KEY с JSON-ключом сервисного аккаунта Google,
у которого есть доступ «Читатель» к обеим таблицам. Без ключа скрипт ничего не делает
и сообщает об этом через GITHUB_OUTPUT (ok=false), чтобы сборка пропустилась без ошибки.

Результат в папке raw/ (в репозиторий не попадает):
  raw/lots.json  — лист «Конкуренты рабочая» (формат ответа values.get)
  raw/deals.json — лист «Все сделки» (формат ответа spreadsheets.get с formattedValue)
  ref.js         — лист «справочник индексов» как window.REF для страницы
"""
import json
import os
import sys
import urllib.parse
from pathlib import Path

LOTS_ID = "17d36Bj_2z4kF29fAn427L8t-cqQE1vUCCoY2dn9fU6Q"   # «Копия Алиса: план, дцо, прайс»
DEALS_ID = "1Woub02QxU2KpezI08kPrjXwPUJcp3tJAZ5SXqmArhJ0"  # «Сделки — сводная (Бестселлер, Алиса, ДМД2)»
API = "https://sheets.googleapis.com/v4/spreadsheets/"
ROOT = Path(__file__).resolve().parent
CDEALS_GID = 775184539                                       # лист сделок конкурентов в книге LOTS_ID


def col_letter(i):
    s = ""
    i += 1
    while i:
        i, r = divmod(i - 1, 26)
        s = chr(65 + r) + s
    return s


def profile_cdeals(title, rows):
    """Обезличенная сводка листа сделок конкурентов для журнала сборки: заголовки, объёмы, варианты значений."""
    from collections import Counter
    head = rows[0] if rows else []
    print(f"Сделки конкурентов: лист «{title}», строк {len(rows) - 1}")
    print("Заголовки: " + " | ".join(f"{col_letter(i)}={h}" for i, h in enumerate(head)))
    cell = lambda r, i: r[i].strip() if i < len(r) and isinstance(r[i], str) else ""
    body = rows[1:]
    print("Проекты (A): " + "; ".join(f"{k}={v}" for k, v in Counter(cell(r, 0) for r in body).most_common(60)))
    for idx in (20, 40):  # U — комнатность, AO — ипотека
        print(f"{col_letter(idx)} варианты: " + "; ".join(f"{k or '(пусто)'}={v}" for k, v in Counter(cell(r, idx) for r in body).most_common(15)))
    dates = sorted({cell(r, 34) for r in body if cell(r, 34)})
    print(f"AI даты: {len(dates)} разных, примеры {dates[:3]} … {dates[-3:]}")
    sample = next((r for r in body if cell(r, 23) and cell(r, 24)), [])
    print(f"Формат X/Y: {cell(sample, 23)!r} / {cell(sample, 24)!r}")


def set_output(name, value):
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write(f"{name}={value}\n")


def main():
    key = os.environ.get("GOOGLE_SA_KEY", "").lstrip("﻿").strip()
    if not key:
        print("::warning::Секрет GOOGLE_SA_KEY не задан, обновление пропущено")
        set_output("ok", "false")
        return

    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession

    creds = service_account.Credentials.from_service_account_info(
        json.loads(key), scopes=["https://www.googleapis.com/auth/spreadsheets.readonly"])
    s = AuthorizedSession(creds)

    def get(url, **params):
        r = s.get(url, params=params, timeout=180)
        if r.status_code != 200:
            sys.exit(f"Ошибка {r.status_code} при чтении {url}: {r.text[:500]}")
        return r.json()

    def values(sid, rng):
        return get(API + sid + "/values/" + urllib.parse.quote(rng, safe=""))

    lots = values(LOTS_ID, "'Конкуренты рабочая'!A1:AK")
    ref = values(LOTS_ID, "'справочник индексов'!A1:P300")
    deals = get(API + DEALS_ID, includeGridData="true", ranges="'Все сделки'!A1:AE3000",
                fields="sheets.data.rowData.values.formattedValue")

    # проверки, чтобы не опубликовать пустой или сломанный сайт
    lv = lots.get("values", [])
    if len(lv) < 500 or (lv[0][0] if lv and lv[0] else "") != "Проект":
        sys.exit(f"Лист «Конкуренты рабочая» выглядит неполным: {len(lv)} строк")
    rows = deals["sheets"][0]["data"][0].get("rowData", [])
    head = [c.get("formattedValue", "") for c in rows[0].get("values", [])] if rows else []
    if len(rows) < 50 or "ЖК" not in head or "Цена в договоре, руб" not in head:
        sys.exit(f"Лист «Все сделки» выглядит неполным: {len(rows)} строк")

    raw = ROOT / "raw"
    raw.mkdir(exist_ok=True)

    # сделки конкурентов (лист с gid CDEALS_GID в той же книге); если листа нет, страница работает без них
    try:
        props = get(API + LOTS_ID, fields="sheets.properties.sheetId,sheets.properties.title")
        title = next((p["properties"]["title"] for p in props.get("sheets", []) if p["properties"]["sheetId"] == CDEALS_GID), None)
        if not title:
            raise RuntimeError(f"лист с gid {CDEALS_GID} не найден")
        cd = values(LOTS_ID, f"'{title}'!A1:BZ")
        cv = cd.get("values", [])
        (raw / "cdeals.json").write_text(json.dumps(cd, ensure_ascii=False), encoding="utf-8")
        profile_cdeals(title, cv)
    except Exception as e:  # noqa: BLE001
        print(f"::warning::Сделки конкурентов не загружены: {e}")
    (raw / "lots.json").write_text(json.dumps(lots, ensure_ascii=False), encoding="utf-8")
    (raw / "deals.json").write_text(json.dumps(deals, ensure_ascii=False), encoding="utf-8")
    (ROOT / "ref.js").write_text("window.REF = " + json.dumps(ref.get("values", []), ensure_ascii=False) + ";", encoding="utf-8")
    print(f"Скачано: лотов {len(lv) - 1}, строк сделок {len(rows) - 1}, строк справочника {len(ref.get('values', []))}")
    set_output("ok", "true")


if __name__ == "__main__":
    main()
