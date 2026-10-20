import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options

def run_test():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument("--headless=new")
    chrome_options.add_argument("--window-size=1280,900")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})

    driver = webdriver.Chrome(options=chrome_options)
    try:
        print("Navigating to http://localhost:8089...")
        driver.get("http://localhost:8089")

        # Wait for Flutter app to initialize
        time.sleep(5)
        driver.save_screenshot("evidence/01_initial_load.png")
        print("Screenshot saved to evidence/01_initial_load.png")

        # Check console logs
        logs = driver.get_log('browser')
        print(f"Browser logs captured: {len(logs)}")
        for log in logs:
            print(f"  [{log['level']}] {log['message']}")

        # Inspect DOM tags
        flt_views = driver.find_elements(By.TAG_NAME, "flutter-view")
        flt_glass = driver.find_elements(By.TAG_NAME, "flt-glass-pane")
        inputs = driver.find_elements(By.TAG_NAME, "input")
        textareas = driver.find_elements(By.TAG_NAME, "textarea")
        print(f"flutter-view count: {len(flt_views)}, flt-glass-pane: {len(flt_glass)}, inputs: {len(inputs)}, textareas: {len(textareas)}")

        # Print page title
        print("Page title:", driver.title)

    finally:
        driver.quit()

if __name__ == "__main__":
    run_test()
