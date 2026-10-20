import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

def test_scan_bon():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument('--headless=new')
    chrome_options.add_argument('--window-size=1280,950')
    chrome_options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get('http://localhost:8089')
        time.sleep(3)

        # Enable accessibility semantics
        placeholder = driver.find_element(By.TAG_NAME, 'flt-semantics-placeholder')
        driver.execute_script("arguments[0].click();", placeholder)
        time.sleep(2)

        # 1. Click "Scan Bon"
        btn_scan = driver.find_element(By.XPATH, "//*[text()='Scan Bon']")
        driver.execute_script("arguments[0].click();", btn_scan)
        time.sleep(2)
        driver.save_screenshot("evidence/bug_scan_01_sheet_opened.png")
        print("[STEP 1] Opened Scan Bon bottom sheet.")

        # Print all visible text
        host_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
        print("Visible options:\n", host_text)

        # 2. Click "Pilih dari Galeri Foto"
        opt_gallery = driver.find_elements(By.XPATH, "//*[contains(text(), 'Pilih dari Galeri Foto')]")
        print("Gallery options found:", len(opt_gallery))
        if opt_gallery:
            driver.execute_script("arguments[0].click();", opt_gallery[0])
            time.sleep(2)
            driver.save_screenshot("evidence/bug_scan_02_after_gallery_click.png")
            print("[STEP 2] Clicked 'Pilih dari Galeri Foto'.")

        # Check console logs
        logs = driver.get_log('browser')
        for l in logs:
            print(f"[{l['level']}] {l['message']}")

    finally:
        driver.quit()

if __name__ == "__main__":
    test_scan_bon()
