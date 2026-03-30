"""
LinkedIn Comment Scraper – Playwright-basiert
Öffnet LinkedIn im Chromium-Browser und scrapt Kommentare von Posts.
"""

import json
import time
import re
from pathlib import Path
from playwright.sync_api import sync_playwright, Page, BrowserContext

BROWSER_DATA_DIR = Path(__file__).parent / ".browser-data"
COMMENTS_DIR = Path(__file__).parent / "comments"


def ensure_login(context: BrowserContext) -> Page:
    """Öffnet LinkedIn und prüft ob eingeloggt. Wenn nicht, wartet auf manuellen Login."""
    page = context.new_page()
    page.goto("https://www.linkedin.com/feed/", wait_until="domcontentloaded")
    time.sleep(3)

    # Prüfe ob Login-Seite angezeigt wird
    if "/login" in page.url or "/checkpoint" in page.url:
        print("\n🔐 Du bist nicht eingeloggt.")
        print("   Bitte logge dich jetzt im geöffneten Browser ein.")
        print("   Warte auf Login...\n")

        # Warte bis der Feed geladen ist (= erfolgreich eingeloggt)
        page.wait_for_url("**/feed/**", timeout=120_000)
        print("   Login erfolgreich!\n")
        time.sleep(2)

    return page


def get_my_recent_posts(page: Page, my_name: str, max_posts: int = 5) -> list[dict]:
    """Navigiert zum eigenen Profil und sammelt die letzten Post-URLs."""
    # Zum eigenen Profil navigieren über "Ich"-Menü
    page.goto("https://www.linkedin.com/in/me/recent-activity/all/", wait_until="domcontentloaded")
    time.sleep(3)

    # Scroll ein paar Mal um Posts zu laden
    for _ in range(3):
        page.evaluate("window.scrollBy(0, 1000)")
        time.sleep(1.5)

    # Finde Post-Links (LinkedIn Activity Page zeigt Posts mit Links)
    post_elements = page.query_selector_all('a[href*="/activity/"]')

    posts = []
    seen_ids = set()
    for el in post_elements:
        href = el.get_attribute("href") or ""
        # Extrahiere die Activity-ID
        match = re.search(r"/activity/(\d+)", href)
        if match and match.group(1) not in seen_ids:
            activity_id = match.group(1)
            seen_ids.add(activity_id)
            posts.append({
                "activity_id": activity_id,
                "url": f"https://www.linkedin.com/feed/update/urn:li:activity:{activity_id}/",
            })
            if len(posts) >= max_posts:
                break

    return posts


def expand_all_comments(page: Page):
    """Klickt alle 'Weitere Kommentare laden' und 'Antworten anzeigen' Buttons."""
    max_clicks = 20
    for _ in range(max_clicks):
        # "Weitere Kommentare laden" / "Load more comments"
        load_more = page.query_selector_all(
            'button.comments-comments-list__load-more-comments-button, '
            'button[aria-label*="Weitere Kommentare"], '
            'button[aria-label*="more comment"], '
            'button[aria-label*="previous replies"]'
        )
        if not load_more:
            break
        for btn in load_more:
            try:
                btn.click()
                time.sleep(1.5)
            except Exception:
                pass

    # "Antworten anzeigen" / "View replies" Buttons
    for _ in range(max_clicks):
        reply_buttons = page.query_selector_all(
            'button[aria-label*="Antwort"], '
            'button[aria-label*="repl"], '
            'button.show-prev-replies'
        )
        if not reply_buttons:
            break
        for btn in reply_buttons:
            try:
                btn.click()
                time.sleep(1.5)
            except Exception:
                pass


def scrape_comments_from_post(page: Page, post_url: str, my_name: str, config: dict) -> dict:
    """Scrapt alle Kommentare und Antworten von einem einzelnen Post."""
    page.goto(post_url, wait_until="domcontentloaded")
    time.sleep(3)

    # Scroll zum Kommentarbereich
    page.evaluate("window.scrollBy(0, 500)")
    time.sleep(2)

    # Alle Kommentare aufklappen
    expand_all_comments(page)
    time.sleep(1)

    min_woerter = config.get("regeln", {}).get("min_woerter", 2)
    ignoriere = [kw.lower() for kw in config.get("regeln", {}).get("ignoriere_keywords", [])]

    # Kommentare auslesen
    # LinkedIn Kommentar-Struktur: articles-Elemente mit verschachtelten Antworten
    comment_elements = page.query_selector_all(
        'article.comments-comment-item, '
        'article.comments-comment-entity, '
        '[data-id][class*="comment"]'
    )

    comments = []
    for el in comment_elements:
        comment = extract_comment_data(el, my_name)
        if comment:
            comments.append(comment)

    # Fallback: Wenn die article-Selektoren nicht greifen, versuche generischeren Ansatz
    if not comments:
        comments = scrape_comments_generic(page, my_name)

    # Filtern und Status bestimmen
    filtered = filter_comments(comments, my_name, min_woerter, ignoriere)

    # Post-Titel/Vorschau extrahieren
    post_preview = ""
    preview_el = page.query_selector(
        '.feed-shared-update-v2__description, '
        '.update-components-text, '
        '[data-ad-preview="message"]'
    )
    if preview_el:
        post_preview = (preview_el.inner_text() or "")[:200]

    activity_id = re.search(r"activity[:/](\d+)", post_url)
    activity_id = activity_id.group(1) if activity_id else "unknown"

    return {
        "activity_id": activity_id,
        "url": post_url,
        "post_vorschau": post_preview,
        "kommentare_gesamt": len(comments),
        "kommentare_zu_beantworten": len([c for c in filtered if c["status"] == "needs_reply"]),
        "kommentare": filtered,
    }


def extract_comment_data(element, my_name: str) -> dict | None:
    """Extrahiert Daten aus einem einzelnen Kommentar-Element."""
    try:
        # Name des Kommentators
        name_el = element.query_selector(
            '.comments-post-meta__name-text, '
            '.comment-entity-meta__name, '
            'span[class*="comment"] a[class*="name"], '
            'a[data-tracking-control-name*="comment"] span'
        )
        name = (name_el.inner_text() if name_el else "").strip().split("\n")[0].strip()

        # Kommentar-Text
        text_el = element.query_selector(
            '.comments-comment-item__main-content, '
            '.comment-entity__content, '
            'span[class*="comment-body"], '
            '[dir="ltr"]'
        )
        text = (text_el.inner_text() if text_el else "").strip()

        if not name or not text:
            return None

        # Antworten (verschachtelte Kommentare)
        reply_elements = element.query_selector_all(
            'article.comments-reply-item, '
            'article.reply-comment-entity, '
            '[class*="replies"] article'
        )

        replies = []
        for reply_el in reply_elements:
            reply = extract_reply_data(reply_el)
            if reply:
                replies.append(reply)

        return {
            "name": name,
            "text": text,
            "replies": replies,
        }
    except Exception:
        return None


def extract_reply_data(element) -> dict | None:
    """Extrahiert Daten aus einer Antwort auf einen Kommentar."""
    try:
        name_el = element.query_selector(
            '.comments-post-meta__name-text, '
            '.comment-entity-meta__name, '
            'a[data-tracking-control-name*="comment"] span, '
            'span[class*="name"]'
        )
        name = (name_el.inner_text() if name_el else "").strip().split("\n")[0].strip()

        text_el = element.query_selector(
            '.comments-comment-item__main-content, '
            '.comment-entity__content, '
            'span[class*="comment-body"], '
            '[dir="ltr"]'
        )
        text = (text_el.inner_text() if text_el else "").strip()

        if not name or not text:
            return None

        return {"name": name, "text": text}
    except Exception:
        return None


def scrape_comments_generic(page: Page, my_name: str) -> list[dict]:
    """Fallback-Scraping wenn die spezifischen Selektoren nicht greifen.
    Nutzt die sichtbare Text-Struktur im Kommentarbereich."""
    comments = []
    try:
        # Versuche über die Kommentar-Container
        containers = page.query_selector_all('[class*="comments-comment-list"] > *')
        for container in containers:
            text_content = container.inner_text().strip()
            if not text_content or len(text_content) < 5:
                continue

            lines = [l.strip() for l in text_content.split("\n") if l.strip()]
            if len(lines) >= 2:
                comments.append({
                    "name": lines[0],
                    "text": " ".join(lines[1:3]),
                    "replies": [],
                })
    except Exception:
        pass

    return comments


def filter_comments(
    comments: list[dict], my_name: str, min_woerter: int, ignoriere: list[str]
) -> list[dict]:
    """Bestimmt für jeden Kommentar ob er beantwortet werden muss."""
    result = []
    my_name_lower = my_name.lower()

    for comment in comments:
        # Eigenen Kommentar überspringen
        if my_name_lower in comment["name"].lower():
            comment["status"] = "eigener_kommentar"
            comment["grund"] = "Eigener Kommentar – übersprungen"
            result.append(comment)
            continue

        # Spam-Check
        text_lower = comment["text"].lower()
        is_spam = any(kw in text_lower for kw in ignoriere)
        if is_spam:
            comment["status"] = "spam"
            comment["grund"] = "Spam-Keyword erkannt – übersprungen"
            result.append(comment)
            continue

        # Zu kurz
        word_count = len(comment["text"].split())
        if word_count < min_woerter:
            comment["status"] = "zu_kurz"
            comment["grund"] = f"Nur {word_count} Wort/Wörter – übersprungen"
            result.append(comment)
            continue

        # Thread-Analyse: Wer hat zuletzt geantwortet?
        replies = comment.get("replies", [])
        if not replies:
            # Keine Antworten → muss beantwortet werden
            comment["status"] = "needs_reply"
            comment["grund"] = "Noch keine Antwort"
        else:
            last_reply = replies[-1]
            if my_name_lower in last_reply["name"].lower():
                # Meine letzte Antwort → prüfe ob danach noch jemand geschrieben hat
                comment["status"] = "bereits_beantwortet"
                comment["grund"] = "Letzte Antwort ist von dir"
            else:
                # Jemand anderes hat nach mir geantwortet → Thread fortsetzen
                comment["status"] = "needs_reply"
                comment["grund"] = f"Neue Antwort von {last_reply['name']} – Thread fortsetzen"

        result.append(comment)

    return result


def scrape(post_url: str | None = None, max_posts: int = 5, config: dict | None = None) -> list[dict]:
    """Hauptfunktion: Scrapt Kommentare von LinkedIn Posts.

    Args:
        post_url: Spezifische Post-URL. Wenn None, werden die letzten Posts gescrapt.
        max_posts: Maximale Anzahl Posts wenn kein spezifischer Post angegeben.
        config: Konfiguration aus config.yaml.

    Returns:
        Liste von Post-Dicts mit Kommentaren.
    """
    if config is None:
        config = {}

    my_name = config.get("mein_name", "Michael Mohr")
    COMMENTS_DIR.mkdir(exist_ok=True)

    results = []

    with sync_playwright() as p:
        # Persistenter Browser-Kontext für Login-Session
        context = p.chromium.launch_persistent_context(
            user_data_dir=str(BROWSER_DATA_DIR),
            headless=False,
            viewport={"width": 1280, "height": 900},
            locale="de-DE",
        )

        try:
            page = ensure_login(context)

            if post_url:
                # Einzelnen Post scrapen
                print(f"\n📄 Scrape Post: {post_url}")
                result = scrape_comments_from_post(page, post_url, my_name, config)
                results.append(result)
            else:
                # Letzte Posts vom Profil holen
                print(f"\n🔍 Suche deine letzten {max_posts} Posts...")
                posts = get_my_recent_posts(page, my_name, max_posts)
                print(f"   {len(posts)} Posts gefunden.\n")

                for i, post in enumerate(posts, 1):
                    print(f"📄 [{i}/{len(posts)}] Scrape Post: {post['url']}")
                    result = scrape_comments_from_post(page, post["url"], my_name, config)
                    results.append(result)
                    print(f"   → {result['kommentare_zu_beantworten']} Kommentare zu beantworten\n")

        finally:
            context.close()

    # Ergebnis speichern
    output_file = COMMENTS_DIR / "comments.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    # Zusammenfassung
    total_to_reply = sum(r["kommentare_zu_beantworten"] for r in results)
    total_comments = sum(r["kommentare_gesamt"] for r in results)
    print(f"\n{'='*50}")
    print(f"📊 Zusammenfassung:")
    print(f"   Posts gescrapt:              {len(results)}")
    print(f"   Kommentare gesamt:           {total_comments}")
    print(f"   Davon zu beantworten:        {total_to_reply}")
    print(f"   Gespeichert in:              {output_file}")
    print(f"{'='*50}\n")

    return results
