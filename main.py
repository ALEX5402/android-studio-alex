import subprocess
from bs4 import BeautifulSoup
import json

with open("studio.html", "r", encoding="utf-8") as file:
    page_content = file.read()
soup = BeautifulSoup(page_content, 'html.parser')
download_table = soup.find("table", class_="download")
output_data = {}

if download_table:
    rows = download_table.find("tbody").find_all("tr") if download_table.find("tbody") else download_table.find_all("tr")
    for row in rows[1:]:
        columns = row.find_all("td")
        platform = columns[0].get_text(separator=" ").strip()
        if "Linux" in platform:
            file_name = columns[1].find("button").get_text(strip=True)
            file_size = columns[2].get_text(strip=True)
            sha_checksum = columns[3].get_text(strip=True)
            version = file_name.split('-')[2]
            output_data = {
                "platform": platform,
                "version": version,
                "fsize": file_size,
                "sha256": sha_checksum
            }

if output_data:
    print(json.dumps(output_data, indent=4))
else:
    print("Linux download data not found.")
