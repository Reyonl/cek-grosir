import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

def test_demo():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument('--headless=new')
    chrome_options.add_argument('--window-size=1280,950')
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get('http://localhost:8089')
        time.sleep(3)

        # Enable accessibility
        placeholder = driver.find_elements(By.TAG_NAME, 'flt-semantics-placeholder')
        if placeholder:
            driver.execute_script("arguments[0].click();", placeholder[0])
            time.sleep(2)

        # Click Scan Bon
        btn_scan = driver.find_element(By.XPATH, "//*[text()='Scan Bon']")
        driver.execute_script("arguments[0].click();", btn_scan)
        time.sleep(2)
        driver.save_screenshot("evidence/demo_01_sheet.png")

        # Click Coba Contoh Bon Grosir (Demo)
        demo_btn = driver.find_element(By.XPATH, "//*[contains(text(), 'Coba Contoh Bon Grosir')]")
        driver.execute_script("arguments[0].click();", demo_btn)
        time.sleep(2)
        driver.save_screenshot("evidence/demo_02_dialog_opened.png")

        # Check text
        host_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
        print("Screen text after Demo Bon:\n", host_text[:500])

    finally:
        driver.quit()

if __name__ == "__main__":
    test_demo()
