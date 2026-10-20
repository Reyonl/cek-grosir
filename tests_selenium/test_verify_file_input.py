import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

def test_fixed_scan():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument('--headless=new')
    chrome_options.add_argument('--window-size=1280,950')
    chrome_options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get('http://localhost:8089')
        time.sleep(3)

        # Enable accessibility
        placeholder = driver.find_elements(By.TAG_NAME, 'flt-semantics-placeholder')
        if placeholder:
            driver.execute_script("arguments[0].click();", placeholder[0])
            time.sleep(2)

        # 1. Click "Scan Bon"
        btn_scan = driver.find_element(By.XPATH, "//*[text()='Scan Bon']")
        driver.execute_script("arguments[0].click();", btn_scan)
        time.sleep(2)
        driver.save_screenshot("evidence/fixed_scan_01_sheet.png")

        # 2. Check options text
        host_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
        print("Visible options:\n", host_text)

        # 3. Click "Pilih File Foto Bon"
        opt_pick = driver.find_elements(By.XPATH, "//*[contains(text(), 'Pilih File Foto Bon')]")
        print("Pick file options found:", len(opt_pick))
        if opt_pick:
            driver.execute_script("arguments[0].click();", opt_pick[0])
            time.sleep(2)
            driver.save_screenshot("evidence/fixed_scan_02_after_click.png")

        # Check console logs for warnings
        logs = driver.get_log('browser')
        warnings = [l['message'] for l in logs if 'File chooser dialog' in l['message']]
        print("User activation warning count:", len(warnings))
        for l in logs:
            if l['level'] in ['SEVERE', 'WARNING']:
                print(f"[{l['level']}] {l['message']}")

    finally:
        driver.quit()

if __name__ == "__main__":
    test_fixed_scan()
