import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

chrome_options = Options()
chrome_options.add_argument('--headless=new')
chrome_options.add_argument('--window-size=1280,900')
driver = webdriver.Chrome(options=chrome_options)

try:
    driver.get('http://localhost:8089')
    time.sleep(3)

    placeholder = driver.find_element(By.TAG_NAME, 'flt-semantics-placeholder')
    driver.execute_script("arguments[0].click();", placeholder)
    time.sleep(2)

    host = driver.find_element(By.TAG_NAME, 'flt-semantics-host')
    nodes = host.find_elements(By.XPATH, './/*[@aria-label or @role or text()]')
    print(f'Accessible semantics nodes after enabling: {len(nodes)}')
    for n in nodes:
        aria = n.get_attribute('aria-label')
        role = n.get_attribute('role')
        text = n.text.strip()
        tag = n.tag_name
        if aria or role:
            print(f"  <{tag}> role='{role}' aria-label='{aria}' text='{text}'")

finally:
    driver.quit()
