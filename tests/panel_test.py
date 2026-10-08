"""Browser regression tests. Requires Playwright and its Chromium browser."""
from pathlib import Path
import sys
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=["--no-sandbox"])
    page = browser.new_page(viewport={"width": 400, "height": 560})
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.add_init_script("""
        window.messages = [];
        window.handlers = {};
        window.panel = {
            on: (name, fn) => { window.handlers[name] = fn; },
            post: (name, data) => { window.messages.push({name, data}); }
        };
    """)
    page.goto((root / "ui/panel.html").as_uri())
    assert page.evaluate("window.messages[0].name") == "ready"
    page.evaluate("window.handlers.update({kill_timers:[{name:'Delbert',minutes:10,display:'10m',colour:'ok'}],visit_timers:[],xp:{window_xp:2000,window_time:'1h',window_rate:2,window_colour:'good',session_xp:2000,session_time:'1h',session_rate:2,session_colour:'good'}})")
    assert page.locator('#xp-window').inner_text() == '2.0k'
    page.locator('.timer-entry').click()
    assert page.evaluate('window.messages.at(-1)') == {'name':'reset','data':{'name':'Delbert'}}
    for selector, message in [('btn-xpreset','xpreset'),('btn-gsxp','gsxp'),('btn-gsxp-all','gsxp'),('btn-gsdt','gsdt'),('btn-reset-all','reset'),('btn-save','dtsave')]:
        page.locator('#'+selector).click()
        assert page.evaluate('window.messages.at(-1).name') == message
    assert not errors, errors
    if len(sys.argv) > 1:
        page.screenshot(path=sys.argv[1])
    browser.close()
print("PASS: panel rendering and actions")
