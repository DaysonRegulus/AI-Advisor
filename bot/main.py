from playwright.sync_api import sync_playwright

def reuse_chrome_profile():
    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(
            user_data_dir="C:\\Users\\Dayson Regulus\\AppData\\Local\\Google\\Chrome\\User Data",  # Chrome base dir
            headless=False,
            args=["--profile-directory=Profile 1","--disable-blink-features=AutomationControlled"],
        )
        page = context.new_page()
        page.goto("https://chat.openai.com", wait_until="load")
        print("✅ You are now inside ChatGPT using your real Chrome session")
        input("Press Enter to exit...")
        context.close()

reuse_chrome_profile()
