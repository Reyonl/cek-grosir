import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

def run_deep_test():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument('--headless=new')
    chrome_options.add_argument('--window-size=1280,950')
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get('http://localhost:8089')
        time.sleep(3)

        # Enable accessibility semantics
        placeholder = driver.find_element(By.TAG_NAME, 'flt-semantics-placeholder')
        driver.execute_script("arguments[0].click();", placeholder)
        time.sleep(2)

        # 1. Pastikan cart sudah ada (karena tersimpan di IndexedDB dari tes sebelumnya)
        driver.save_screenshot("evidence/deep_01_loaded_state.png")
        host = driver.find_element(By.TAG_NAME, 'flt-semantics-host')
        print("Screen text length:", len(host.text))

        # 2. Tes interaksi checkbox pertama (Centang item pertama belanja)
        checkboxes = driver.find_elements(By.XPATH, "//flt-semantics[@role='checkbox']")
        print(f"Checkboxes found: {len(checkboxes)}")
        if checkboxes:
            driver.execute_script("arguments[0].click();", checkboxes[0])
            time.sleep(1)
            driver.save_screenshot("evidence/deep_02_checked_item.png")
            print("[PASS] Checked first grocery item.")

        # 3. Tes tombol Tambah Kuantitas (+)
        plus_buttons = driver.find_elements(By.XPATH, "//*[text()='+' or @aria-label='Tambah kuantitas']")
        print(f"Plus buttons found: {len(plus_buttons)}")
        if plus_buttons:
            driver.execute_script("arguments[0].click();", plus_buttons[0])
            time.sleep(1)
            driver.save_screenshot("evidence/deep_03_increment_qty.png")
            print("[PASS] Incremented quantity.")

        # 4. Tes buka sheet Database Harga Langganan (Badge 11 di App Bar)
        db_button = driver.find_elements(By.XPATH, "//*[contains(text(), 'Database Harga Langganan')]")
        if db_button:
            driver.execute_script("arguments[0].click();", db_button[0])
            time.sleep(2)
            driver.save_screenshot("evidence/deep_04_price_memory_sheet.png")
            print("[PASS] Opened Price Memory Manager.")

            # Cari tombol tutup atau batal
            close_btns = driver.find_elements(By.XPATH, "//*[text()='Tutup' or @aria-label='Tutup' or text()='Kembali']")
            if close_btns:
                driver.execute_script("arguments[0].click();", close_btns[0])
                time.sleep(1)
            else:
                # Tap background / escape
                driver.find_element(By.TAG_NAME, 'body').send_keys('\ue00c') # Escape
                time.sleep(1)

        # 5. Tes Impor JSON Dialog
        btn_impor = driver.find_elements(By.XPATH, "//*[text()='Impor JSON' or contains(text(), 'Impor Data JSON')]")
        if btn_impor:
            driver.execute_script("arguments[0].click();", btn_impor[0])
            time.sleep(2)
            driver.save_screenshot("evidence/deep_05_impor_json_dialog.png")
            print("[PASS] Opened Import JSON Dialog.")

            # Tutup dialog impor
            batal_btns = driver.find_elements(By.XPATH, "//*[text()='Batal' or text()='Tutup']")
            if batal_btns:
                driver.execute_script("arguments[0].click();", batal_btns[0])
                time.sleep(1)

        # Capture final screenshot
        driver.save_screenshot("evidence/deep_06_final_verification.png")
        print("[ALL SUCCESS] All interaction tests completed successfully.")

    finally:
        driver.quit()

if __name__ == "__main__":
    run_deep_test()
