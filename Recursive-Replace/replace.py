import glob
root_path = '/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test'
for filepath in glob.iglob(root_path + '/**/*.txt', recursive=True):
    print(filepath)
    with open(filepath) as file:
        s = file.read()
        # print('before:', s)
        s = s.replace('Hello', 'Hi')
        # print('after:', s)
    with open(filepath, "w") as file:
        file.write(s)
