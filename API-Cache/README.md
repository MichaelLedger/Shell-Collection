### Auto fetch preferences

1) Go To The Script Directory
    - cd PROJECT_ROOT/scripts/APICache

2) Execute Fetch Preferences Script
    - FP: python3 request.py fp 3.67.0 -c us,uk
    - PB: python3 request.py pb 2.43.0 -c us,uk
    - PT: python3 request.py pt 7.29.0 -c us,uk
    - PT: python3 request.py pt 7.44.0 -c all
    - ET: python3 request.py et 6.5.0 -c all

# country: "us", "uk", "fr", "ie", "it", "es", "de", "nl"
# python3 request.py {project_name} {project_num} -c {country}

3）Replace Project Preferences Files
    - remove old preferences files from project & add new preferences files

# Notes: If you encounter the following log information when executing the script, please notify the server to modify it in time.

# 👮‍♂️👮‍♂️ Preferences exist null value 👮‍♂️👮‍♂️
# ['**','**']
# 👮‍♂️👮‍♂️ Please notify the backend 👮‍♂️👮‍♂️

