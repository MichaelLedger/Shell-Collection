import argparse
from fileinput import filename
import glob
from importlib.resources import path
import json
# from macpath 
# import split
# import subprocess
# import webbrowser
import os
import os.path
import re
import time
import urllib.request
import uuid
import plistlib
import xml.etree.ElementTree as ET
from urllib import parse
from urllib.parse import (urlencode, unquote, urlparse, parse_qsl, ParseResult)
import hmac
import hashlib
import requests

proxies = { #requests and charles are being used at the same time
    "http": None,
    "https": None,
}
app_group = ["FP", "PB", "PT", "ET"]
app_country = ["US", "UK", "FR", "IE", "IT", "ES", "DE", "NL"]
pt_app_country = ["US", "UK", "FR", "IE", "IT", "ES", "DE", "NL", "PL", "SE","BE"]
et_app_country = ["US", "UK"]
app_directory = {
    "PB": "XXX",
    "PT": "XXX",
    "FP": "XXX",
    "ET": "XXX",
}
project_file = {
    "PB": "XXX.xcodeproj/project.pbxproj",
    "PT": "XXX.xcodeproj/project.pbxproj",
    "FP": "XXX.xcodeproj/project.pbxproj",
    "ET": "XXX.xcodeproj/project.pbxproj",
}

appSessionId = str(uuid.uuid4()).upper() #"00000000-0000-0000-0000-000000000000"
appDeviceId = str(uuid.uuid4()).upper()
accountEmail = 'appstoreconnect@xxx.com'
accountPwd = 'xxx'

def parse_arguments():
    # Create argument parser
    parser = argparse.ArgumentParser()

    # Positional mandatory arguments
    parser.add_argument("app_name", help="PB,FP,PT", type=str)
    parser.add_argument("app_version", help="3.50.0", type=str)

    # Optional arguments
    parser.add_argument("-c", "--country",
                        help="like: US,UK,FR,IE,IT", type=str)

    argument = parser.parse_args()
    return argument


def get_common_params(language):
    query_params = {'_language': language,
                    '_full_version': get_full_version(),
                    '_phone_type': 'iPhone-4_7',
                    '_timestamp': int(round(time.time() * 1000)),
                    '_sessionId': appSessionId,
                    '_device': appDeviceId,
                    '_app': get_app_name(language),
                    '_screen': "com_welcome"
                    }
    return query_params 
    
def get_preferences(country, language, products):
    def get_project_filepath(country):
        dir_project = os.path.abspath(os.path.join(os.getcwd(), "../../.."))
        project_path = "{dir_project}/{app_path}/{prj_file}".format(
            dir_project=dir_project, app_path=app_directory[app_name],
            prj_file=project_file[app_name])
        return project_path

    def update_project_fileRef(file, old_file_name, new_file_name):
        file_data = ""
        with open(file, "r", encoding="utf-8") as f:
            for line in f:
                if old_file_name in line:
                    line = line.replace(old_file_name, new_file_name)
                file_data += line
        with open(file, "w",encoding="utf-8") as f:
            f.write(file_data)
            print("😀 *" + old_file_name + "->" + new_file_name + "* update project file finish" + " 😀")

    def get_res_path(country_language, country):
        language = str(country_language).split("-")[0]
        dir_project = os.path.dirname(os.path.realpath(__file__))
        if app_name == "PT":
            flavors = "main"
            country = str(country_language).split("-")[1]
        else:
            if country == "IE":
                flavors = "uk_fla_IE"
            else:
                flavors = "{country}_fla".format(country=str(country).lower())
        res = "{dir}/{app}/src/{f}/res/".format(dir=dir_project,
                                                app=app_directory[app_name],
                                                f=flavors)
        dimens_path = "{res}values-{l}-r{c}/dimens.xml".format(res=res, l=language,
                                                            c=str(
                                                                country).upper())
        if os.path.isfile(dimens_path) and has_preference_version(dimens_path):
            return dimens_path
        dimens_path = "{res}values-{l}/dimens.xml".format(res=res, l=language)
        if os.path.isfile(dimens_path) and has_preference_version(dimens_path):
            return dimens_path
        return "{res}values/dimens.xml".format(res=res)
    
    query_params = get_common_params(language)
    query_params["_method"] = 'app.launch'
    body_params = {'first_launch': 1,
                   'client_params': '{"is_app_enter_foreground":"0",'
                                    '"first_launch":"1",'
                                    '"has_uninstalled_apps":"0",'
                                    '"has_fp_install":"0",'
                                    '"has_pb_install":"0",'
                                    '"has_pt_install":"0",'
                                    '"has_ink_install":"0",'
                                    '"has_fc_install":"0",'
                                    '"has_fg_install":"0",'
                                    '"push_notif_onoff":"on"}',
                   'multiple_data': """{"preferences":{"refresh":true},"register":{"refresh":true}}"""
                   }
    base_url = get_base_url(country)
    data = send_request_v3(base_url, query_params, body_params)
    json_data = data["preferences"]
    for key in list(json_data.keys()):
        if json_data[key] is None:
            del json_data[key]
            continue
    if len(products) > 0:
        json_data["products"] = products
    json_content = json.dumps(json_data)
    re_rule = r'"[A-z]*?": null'
    re_pattern = re.compile(re_rule)
    re_lists = re_pattern.findall(json_content)

    if len(re_lists) > 0:
        for re_str in re_lists:
            re_str1 = re_str + ", "
            re_str2 = ", " + re_str
            json_content = json_content.replace(re_str1,'')
            json_content = json_content.replace(re_str2,'')
        print("👮‍♂️👮‍♂️ Preferences exist null value 👮‍♂️👮‍♂️")
        print(re_lists)
        print("👮‍♂️👮‍♂️ Please notify the backend 👮‍♂️👮‍♂️\n")
    json_string = json.loads(json_content)
    # print(json_string)
    preferences_path = get_preference_path(country)
    country_language = get_country_lauguage(country,language)
    file_version = get_file_version(preferences_path, country_language)
    if file_version == 0:
        print("👮‍♂️👮‍♂️ update preference error,local old preference file not exist 👮‍♂️👮‍♂️")
        exit()
    old_file_name = "{preferenceV}{v}{name}".format(preferenceV=get_preferenceV(),
                                             v='{:0>2d}'.format(file_version),
                                             name=get_preference_json(country_language))
    paths = get_files(preferences_path, old_file_name)
    # print(paths)
    if len(paths) == 0:
        old_file_name = "{preferenceV}{v}{name}".format(preferenceV=get_preferenceV(),
                                             v='{:0>2d}'.format(file_version),
                                             name=get_preference_plist(country_language))
        paths = get_files(preferences_path, old_file_name)

    if len(paths) > 0:
        # res_path = get_res_path(language, country)
        # print("res path " + res_path)
        version_path = "{path}/{name}".format(path=preferences_path, name="preference_lib_version.plist")
        version_key = "{preferenceV}{name}".format(preferenceV="preference_version", name=country_language)
        file_version = file_version + 1
        new_path = "{path}/{preferenceV}{v}{name}".format(path=preferences_path,
                                                preferenceV=get_preferenceV(),
                                                v='{:0>2d}'.format(file_version),
                                             name=get_preference_json(country_language))
        # print("res path " + new_path)
        new_file_name = "{preferenceV}{v}{name}".format(preferenceV=get_preferenceV(),
                                             v='{:0>2d}'.format(file_version),
                                             name=get_preference_plist(country_language))

        save_file(json_string, paths, new_path)
        update_preference_version(version_path, version_key, file_version, new_file_name)
        prjFilename = get_project_filepath(country)
        new_jsonfile_name = "{preferenceV}{v}{name}".format(preferenceV=get_preferenceV(),
                                        v='{:0>2d}'.format(file_version),
                                        name=get_preference_json(country_language))
        update_project_fileRef(prjFilename, old_file_name, new_jsonfile_name)
        old_file_path = "{path}/{file_name}".format(path=preferences_path, file_name=old_file_name)
        os.remove(old_file_path)
        print("😀 *" + old_file_path + "* remove old preference file finish" + " 😀")
        print("")
        
        # validate app keys
        validate_app_keys(json_data, preferences_path, country)
        # validate app configs
        validate_app_configs(json_data, preferences_path, country)
    print("")
        
def validate_app_keys(json_data, preferences_path, country):
    local_plist_name = get_plist_name(country)
    local_plist_path = "{path}/{plist_name}{suffix_name}".format(path=preferences_path, plist_name= local_plist_name, suffix_name="-info.plist")
    print("local plist path = {list_path}".format(list_path=local_plist_path))
    
    local_appsflyer = read_plist_value(local_plist_path,"AppsflyerDevKey")
    local_amplitude_dev = read_plist_value(local_plist_path,"AmplitudeDevAppID")
    local_amplitude_pro = read_plist_value(local_plist_path,"AmplitudeAppID")

    print("\033[4;35;43m *** begin validate app keys ***")

    if "sdk_app_keys" in json_data:
        sdk_app_keys = json_data["sdk_app_keys"]
        if "iOS" in sdk_app_keys:
            ios_sdk_app_keys = sdk_app_keys["iOS"]
            if "appsflyer" in ios_sdk_app_keys:
                remote_appsFlyer_key = ios_sdk_app_keys["appsflyer"]
            if "amplitude_dev" in ios_sdk_app_keys:
                remote_amplitude_dev = ios_sdk_app_keys["amplitude_dev"]
            if "amplitude_pro" in ios_sdk_app_keys:
                remote_amplitude_pro = ios_sdk_app_keys["amplitude_pro"]
    print("###### AppsFlyer ######")
    print("local_key={local_appsflyer_key}, remote_key={remote_appsflyer_key}".format(local_appsflyer_key=local_appsflyer,remote_appsflyer_key=remote_appsFlyer_key))
    convert_local_appsflyer = local_appsflyer.replace('\\', '')
    if convert_local_appsflyer == remote_appsFlyer_key:
        print("😀 appsflyer validate success 😀")
    else:
        print("👮‍♂️👮‍♂️ appsflyer validate fail 👮‍♂️👮‍♂️")
    print("")
    print("###### Amplitude ######")
    print("local_dev_key={local_amplitude_dev_key}, remote_dev_key={remote_amplitude_dev_key}".format(local_amplitude_dev_key=local_amplitude_dev,remote_amplitude_dev_key=remote_amplitude_dev))
    print("local_pro_key={local_amplitude_pro_key}, remote_pro_key={remote_amplitude_pro_key}".format(local_amplitude_pro_key=local_amplitude_pro,remote_amplitude_pro_key=remote_amplitude_pro))
    convert_local_amplitude_dev = local_amplitude_dev.replace('\\', '')
    convert_local_amplitude_pro = local_amplitude_pro.replace('\\', '')
    if convert_local_amplitude_dev == remote_amplitude_dev and convert_local_amplitude_pro == remote_amplitude_pro:
        print("😀 amplitude validate success 😀")
    else:
        print("👮‍♂️👮‍♂️ amplitude validate fail 👮‍♂️👮‍♂️")
    print("*** end validate app keys ***\033[0m")
    
def validate_app_configs(json_data, preferences_path, country):
    local_plist_name = get_plist_name(country)
    local_plist_path = "{path}/{plist_name}{suffix_name}".format(path=preferences_path, plist_name= local_plist_name, suffix_name="-info.plist")
    local_entitlements_path = "{path}/{plist_name}{entitle_name}".format(path=preferences_path, plist_name= local_plist_name, entitle_name=".entitlements")
    print("local entitlements path = {list_path}".format(list_path=local_entitlements_path))

    
    local_apple_app_id = read_plist_value(local_plist_path,"AppleAppID")
    local_facebook_app_id = read_plist_value(local_plist_path,"FacebookAppID")

    print("\033[4;35;43m *** begin validate app configs ***")
    print(("###### {app_country} AppleAppID ######").format(app_country=country))
    print("apple_app_id={apple_app_id}".format(apple_app_id=local_apple_app_id))
    print("")
    print(("###### {app_country} FacebookAppID ######").format(app_country=country))
    print("facebook_app_id={facebook_app_id}".format(facebook_app_id=local_facebook_app_id))
    print("")
    local_entitlements_keys = ["com.apple.developer.associated-domains", "com.apple.security.application-groups", "keychain-access-groups"]
    read_and_print_entitlements(country,local_entitlements_path, local_entitlements_keys)

    print("*** end validate app configs ***\033[0m")

def read_and_print_entitlements(country,file_path, print_keys):
    # open and read .entitlements file
    with open(file_path, 'rb') as f:
        entitlements = plistlib.load(f)
    
    # print key/value
    for key, value in entitlements.items():
        if key in print_keys:
            print(f"###### {country} {key} ######")
            print(f"{value}")
            print("")

def create_account(country, language):
    query_params = get_common_params(language)
    query_params["_method"] = 'account.create'
    query_params['_screen'] = 'com_sign_up'
    if app_name == "PB":
        query_params['_host_app'] = get_app_name(language)
    query_params.pop('_phone_type')
    query_params['_device'] = appDeviceId
    query_params['_sessionId'] = appSessionId
    body_params = {'email': accountEmail,
                'first_name': 'appstore',
                'last_name': 'connect',
                'password': accountPwd,
                }
    base_url = get_base_url(country)
    data = send_request_v3(base_url, query_params, body_params, False)
    result = data["result"]
    message = app_name+country + ' ' + language + ' ' + accountEmail + ' pwd: ' + accountPwd
    if result == True:
        message += " #Create success"
    else:
        errCode = str(data["error"])
        if errCode == "16":
            title = data["title"]
            message += " #" + title
        else:
            print(data)
            message += "; " + "failed to create account"
    print("😀", message, "😀", "\n")
    return message

def get_product_preferences(country, language):
    query_params = get_common_params(language)
    query_params["_method"] = 'site.get_products'
    body_params = {}
    base_url = get_base_url(country)
    data = send_request_v3(base_url, query_params, body_params)
    if len(data) > 0:
        products = data["products"]
        get_preferences(c, app_language, products)
    else:
        print("error!!!!,Not get products data，exit..............")
        exit()

def send_request(url, body_params):
    # print("url: = " + url)
    data = urllib.parse.urlencode(body_params)
    data = data.encode('ascii')
    req = urllib.request.Request(
        url, data,
        headers={'user-agent': 'FREEPRINT iOS/{v}'.format(v=app_version)})
    with urllib.request.urlopen(req) as response:
        raw_response = response.read()
        data = json.loads(raw_response)
        result = json.loads(json.dumps(data["result"]))
        if not result:
            print("error!!!!,Backend returns incorrect data，exit..............")
            exit()
        return data

def send_request_v2(url, body_params, checkErr=True):
    def get_sign(url):
        sign_key = "^Pac#St0p!C@v1dI9"
        sign_params = get_sign_params(url)
        algorithm = hashlib.sha256
        sign_bytes = hmac_hash(algorithm, sign_key, sign_params)
        return sign_bytes

    def get_sign_params(url):
        timestamp=parse.parse_qs(parse.urlparse(url).query)['_timestamp'][0]
        device=parse.parse_qs(parse.urlparse(url).query)['_device'][0]
        full_version=parse.parse_qs(parse.urlparse(url).query)['_full_version'][0]
        screen=parse.parse_qs(parse.urlparse(url).query)['_screen'][0]
        query_params = {'_full_version': full_version,
                        '_device': device,
                        '_screen': screen,
                        '_timestamp': str(timestamp),
                        }
        sign_str = ""
        for key, value in query_params.items():
            sign_str = sign_str + key + value
        return sign_str
    #print("url: = " + url)
    data = urllib.parse.urlencode(body_params)
    data = data.encode('ascii')
    sign = get_sign(url)
    headers = {'user-agent': 'FREEPRINT iOS/{v}'.format(v=app_version),
               '_sign': sign
               }
    raw_response = requests.post(url, params=data, headers=headers, proxies=proxies)
    data = json.loads(raw_response.content)
    result = json.loads(json.dumps(data["result"]))
    if checkErr and not result:
        print("error!!!!,Backend returns incorrect data，exit..............")
        print(data)
        #delete_branch()
        exit()
    return data

def send_request_v3(baseUrl, getParams = {}, postParams = {}, checkErr=True):
    def get_sign_v2(getParams, postParams):
        getList = []
        for key, value in getParams.items():
            getList.append(str(key) + str(value))
        postList = []
        for key, value in postParams.items():
            postList.append(str(key) + str(value))
        orderedGetList = sorted(getList)
        orderedPostList = sorted(postList)
        signContent = ""
        for item in orderedGetList:
            signContent += item
        for item in orderedPostList:
            signContent += item
        algorithm = hashlib.sha256
        sign_bytes = hmac_hash(algorithm, "nfK5zbGP1MtPr3pz", signContent)
        #print("signContent:\n" + signContent + "\nsign_bytes:\n" + sign_bytes + "\n")
        return sign_bytes

    url = add_url_params(baseUrl, getParams)
    sign_v2 = get_sign_v2(getParams, postParams)
    data = urllib.parse.urlencode(postParams)
    data = data.encode('ascii')
    headers = {'user-agent': 'FREEPRINT iOS/{v}'.format(v=app_version)}
    headers['sign'] = sign_v2
    headers['sign-ver'] = "1"
    raw_response = requests.post(url, params=data, headers=headers, proxies=proxies)
    method = baseUrl
    if "_method" in getParams.keys():
        method = getParams["_method"]
    language = ""
    if "_language" in getParams.keys():
        language = getParams["_language"]
    print("### ### ### ###", language, method, "### ### ### ###")
    print("URL:\n", url)
    print("POST:\n", postParams)
    print("HEADERS:\n", headers)
    data = json.loads(raw_response.content)
    result = json.loads(json.dumps(data["result"]))
    if checkErr and not result:
        print("error!!!!,Backend returns incorrect data，exit..............")
        print(data)
        #delete_branch()
        exit()
    return data

def hmac_hash(algorithm, key, message):
    signature = hmac.new(
        bytes(key, 'latin-1'),
        msg=bytes(message, 'latin-1'),
        digestmod=algorithm
    ).hexdigest().upper()
    return signature

def save_file(json_string, paths, new_path):
    if len(paths) > 0:
        path = paths[0]
        save_json(json_string, new_path)
        # os.remove(path)
        # subprocess.call(["git", "add", path])
        # print(new_path + " save success")
        # subprocess.call(["git", "add", new_path])

def get_preference_path(country):
    # dir_project = os.path.dirname(os.path.realpath(__file__))
    dir_project = os.path.abspath(os.path.join(os.getcwd(), "../../.."))
    if app_name == "PT":
        flavors = "fpus"
    elif app_name == "ET":
        flavors = "easytiles"
    else:
        if app_name == "PB":
            flavors = "pb{country}".format(country=str(country).lower())
        else:
            flavors = "fp{country}".format(country=str(country).lower())
    preferences_path = "{dir_project}/{app_path}/{flavors}".format(
        dir_project=dir_project, app_path=app_directory[app_name],
        flavors=flavors)
    return preferences_path

def get_plist_name(country):
    # dir_project = os.path.dirname(os.path.realpath(__file__))
    dir_project = os.path.abspath(os.path.join(os.getcwd(), "../../.."))
    if app_name == "PT":
        plistName = "fpus"
    else:
        if app_name == "PB":
            plistName = "pb{country}".format(country=str(country).lower())
        else:
            plistName = "fp{country}".format(country=str(country).lower())
    return plistName

def has_preference_version(dimens_path):
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    tree = ET.parse(dimens_path, parser)
    root = tree.getroot()
    for child in root:
        if "name" not in child.attrib:
            continue
        name = child.attrib['name']
        if name == 'preference_version':
            return True
    return False

def update_preference_version(version_path, version_key, file_version, new_file_name):
    # read
    rb = open(version_path, 'rb')
    rb_dict = plistlib.load(rb)

    # change value
    rb_dict[version_key] = str('{:0>2d}'.format(file_version))

    # write
    wb = open(version_path, 'wb')
    plistlib.dump(rb_dict, wb)
    wb.close()
    print("😀 *" + new_file_name + "* update preference finish" + " 😀")

def read_plist_value(plist_path, plist_key):
    # read
    rb = open(plist_path, 'rb')
    rb_dict = plistlib.load(rb)

    # read value
    return rb_dict[plist_key]

def get_preference_plist(country_language):
    return "{local_name}.plist".format(local_name=country_language)

def get_preference_json(country_language):
    return "{local_name}.json".format(local_name=country_language)

def get_price_name(country_language):
    language = str(country_language).split("-")[0]
    country = str(country_language).split("-")[1]
    return "price.json.{country}.{language}.".format(country=country,
                                                     language=language)

def get_product_name(country_language):
    language = str(country_language).split("-")[0]
    country = str(country_language).split("-")[1]
    return "products.json.{country}.{language}.".format(country=country,
                                                        language=language)

def save_json(json_string, path):
    with open(path, 'w') as outfile:
        json.dump(json_string, outfile)

def get_country_lauguage(country, language): 
    localize_name = get_localize_name(country, language)
    country_language = "-{localizeName}".format(localizeName=localize_name)
    return country_language

def get_file_version(preferences_path, name):
    file_names = get_files(preferences_path, name)
    file_version = 0
    for file_name in file_names:
        preferenceV = get_preferenceV()
        arrays = str(str(file_name).split(name)[0]).split(preferenceV)
        cur_version = arrays[len(arrays) - 1]
        if "-" in cur_version:
            cur_version = str(cur_version).split("-")[0]
        if int(cur_version) > file_version:
            file_version = int(cur_version)
    # print(file_version)
    return file_version


def get_files(preferences_path, file_name):
    preferenceV = get_preferenceV()
    if ".plist" in file_name or ".json" in file_name:
        glob_string = "{path}/{name}".format(path=preferences_path, name=file_name)
        lists = glob.glob(glob_string)
    else:
        glob_string = "{path}/{prefixV}*{name}.json".format(path=preferences_path, prefixV=preferenceV, name=file_name)
        lists = glob.glob(glob_string)
        if len(lists) == 0:
            glob_string = "{path}/{prefixV}*{name}.plist".format(path=preferences_path, prefixV=preferenceV, name=file_name)
            lists = glob.glob(glob_string)
    return lists

def get_preferenceV():
    return "preferencesV"

def get_full_version():
    return app_version + ".88888"

def get_base_url(country):
    if app_name == "ET":
        if country == 'US':
            return 'https://api.xxx.com/api/'
        else:
            return 'https://api-eu.xxx.com/api/'
    else:
        if country == 'US' or country == 'CA':
            url = "https://{app}.xxx.com/api/".format(
                app=str(app_name).lower())
        else:
            url = "https://{app}.xxx.co.uk/api/".format(
                app=str(app_name).lower())
        return url

def parse_country_name(country_language):
    country = str(country_language).split("-")[1].upper()
    if country == "GB":
        country = "UK"
    return country

def get_app_name(country_language):
    country = parse_country_name(country_language)
    return "iOS-" + app_name + country + "-" + app_version

def get_app_env(country):
    country_language = []
    if "US" == country:
        country_language.append("en-US")
        if app_name == "FP":
            country_language.append("es-US")
    if "UK" == country:
        country_language.append("en-GB")
    if "IE" == country:
        country_language.append("en-IE")
    if "FR" == country:
        country_language.append("fr-FR")
    if "IT" == country:
        country_language.append("it-IT")
    if "ES" == country:
        country_language.append("es-ES")
    if "DE" == country:
        country_language.append("de-DE")
        country_language.append("de-AT")
    if app_name != "PT" and "NL" == country:
        country_language.append("nl-NL")
        country_language.append("pl-PL")
        country_language.append("sv-SE")
        country_language.append("fr-BE")
        country_language.append("nl-BE")
    if app_name == "PT":
        if "NL" == country:
            country_language.append("nl-NL")
        if "PL" == country:
            country_language.append("pl-PL")
        if "SE" == country:
            country_language.append("sv-SE")
        if "BE" == country:
            country_language.append("fr-BE")
            country_language.append("nl-BE")
    return country_language    

def get_localize_name(country, country_language):
    if len(country) > 0 and len(country_language) > 0:
        localizeName = str(country).lower()
        if "es-US" == country_language:
            localizeName = "us-es"
        if "fr-CA" == country_language:
            localizeName = "ca-fr"
        if "de-AT" == country_language:
            localizeName = "at"
        if "pl-PL" == country_language:
            localizeName = "pl"
        if "sv-SE" == country_language:
            localizeName = "sv"
        if "fr-BE" == country_language:
            localizeName = "be-fr"
        if "nl-BE" == country_language:
            localizeName = "be-nl"
        return localizeName
    else:
        print("error country or country_language")
        exit()

def add_url_params(url, params):
    url = unquote(url)
    parsed_url = urlparse(url)
    get_args = parsed_url.query
    parsed_get_args = dict(parse_qsl(get_args))
    parsed_get_args.update(params)
    encoded_get_args = urlencode(parsed_get_args, doseq=True)
    new_url = ParseResult(
        parsed_url.scheme, parsed_url.netloc, parsed_url.path,
        parsed_url.params, encoded_get_args, parsed_url.fragment
    ).geturl()
    return new_url


if __name__ == '__main__':
    # Parse the arguments
    args = parse_arguments()
    # Raw print arguments
    print("You are running the script with arguments: ")
    for a in args.__dict__:
        print(str(a) + ": " + str(args.__dict__[a]))
    app_name = str(args.app_name).upper()
    if app_name not in app_group:
        print("error arguments for app name  ,app name should be fp ,pb or "
              "pt, like : python3 request.py fp 3.66.0 -c us")
        exit()
    app_version = str(args.app_version)
    app_branch = app_version
    is_match = re.search(r"^([1-9]\d|[1-9])(\.([1-9]\d|\d)){2}$", app_version)
    if not is_match:
        print("error app version ,app version should *.*.*, like : python "
              "auto_fetch.py pb 2.35.0 -c us,uk")
        exit()
    country_list = app_country
    if app_name == "PT":
        country_list = pt_app_country
    elif app_name == "ET":
        country_list = et_app_country

    if str(args.country).upper() != "NONE":
        if len(str(args.country).upper().split(",")) > 0 and str(args.country).upper() != "ALL":
            country_list = str(args.country).upper().split(",")

    print()
    country2info = {}
    for c in country_list:
        languages = get_app_env(c)
        def supportProductsFn(appLanguage):
            if appLanguage == 'en-US' or appLanguage == 'en-GB':
                return True
            else:
                return True # all region support product currently
        for app_language in languages:
            if app_name == "PT" and supportProductsFn(app_language):
                get_product_preferences(c, app_language)
            else:
                get_preferences(c, app_language, {})
            infactCountry = parse_country_name(app_language)
            if infactCountry not in country2info.keys():
                country2info[infactCountry] = {'country':c, 'language':app_language}

    #create appstoreconnect@xxx.com account
    messages = []
    for info in country2info.values():
        country = info['country']
        language = info['language']
        msg = create_account(country, language)
        messages.append(msg)
    def printSplitLine(endTag = ''):
        line = ""
        if len(messages) > 0:
            lineLen = len(messages[0])
            for i in range(lineLen):
                line += "+"
        print(line+endTag)
    printSplitLine("")
    for msg in messages:
        print(msg)
    printSplitLine("\n")
