# Recursively find and replace string in files by python

## Prepare

For those using Python 3.5+ you can now use a glob recursively with the use of ** and the recursive flag.

`replace.py` replacing 'Hello' with 'Hi' for all .txt files.

`replace_ios.py` replacing 'Hello' with 'Hi' for all iOS relative files(`*.{h,m,mm,xib,storyboard,swift}`).

`rename_oc_class_name.py` rename Objective-C class name

`batch_rename_oc_class_name.py` batch rename Objective-C class name according to `rename_classes.json`

## Usage
`python3 replace.py`

`python3 replace_ios.py`

`python3 rename_oc_class_name.py`

`python3 batch_rename_oc_class_name.py`

## Console example:
```
➜  Replace-String git:(master) ✗ python3 replace.py
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/b.txt
before: Hello World!
after: Hi World!
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/a.txt
before: Hello World!
after: Hi World!
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d.txt
before: Hello World!
after: Hi World!
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d/e.txt
before: Hello World!
after: Hi World!
```

```
➜  Replace-String git:(master) ✗ python3 replace_ios.py
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/fake.h
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/fake.swift
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/fake.xib
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/fake.mm
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/fake.storyboard
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/fake.m
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/fake.h
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/fake.swift
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/fake.xib
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/fake.mm
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/fake.storyboard
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/fake.m
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d/fake.h
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d/fake.swift
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d/fake.xib
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d/fake.mm
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d/fake.storyboard
/Users/gavinxiang/Downloads/Shell-Collection/Replace-String/Test/c/d/fake.m
```

```
➜  Recursive-Replace git:(master) ✗ python3 rename_oc_class_name.py                                                                       
['rename_oc_class_name.py']
Enter Objective-C original class name:
A
Enter Objective-C renamed class name:
B
Enter your project absolute path:
/Users/gavinxiang/Downloads/iOS_Project
original_formats: ['[A ', ' A;', 'A*', 'A *', ' A:', ' A :', 'A.h', 'A.m']
renamed_formats: ['[B ', ' B;', 'B*', 'B *', ' B:', ' B :', 'B.h', 'B.m']
will replace ` [A  ` with ` [B  `
will replace `  A; ` with `  B; `
will replace ` A* ` with ` B* `
will replace ` A * ` with ` B * `
will replace `  A: ` with `  B: `
will replace `  A : ` with `  B : `
will replace ` A.h ` with ` B.h `
will replace ` A.m ` with ` B.m `
```

```
➜  Recursive-Replace git:(master) ✗ python3 rename_oc_class_name.py A B /Users/gavinxiang/Downloads/iOS_Project
['rename_oc_class_name.py', 'A', 'B', '/Users/gavinxiang/Downloads/iOS_Project']
original_class: A
renamed_class: B
root_path: /Users/gavinxiang/Downloads/iOS_Project
original_formats: ['[A ', ' A;', 'A*', 'A *', ' A:', ' A :', 'A.h', 'A.m']
renamed_formats: ['[B ', ' B;', 'B*', 'B *', ' B:', ' B :', 'B.h', 'B.m']
will replace ` [A  ` with ` [B  `
will replace `  A; ` with `  B; `
will replace ` A* ` with ` B* `
will replace ` A * ` with ` B * `
will replace `  A: ` with `  B: `
will replace `  A : ` with `  B : `
will replace ` A.h ` with ` B.h `
will replace ` A.m ` with ` B.m `
```

```
python3 batch_rename_oc_class_name.py <project_or_sdk_root_path>
```

## Reference

[Recursively find and replace string in text files](https://stackoverflow.com/questions/4205854/recursively-find-and-replace-string-in-text-files)

[Python glob multiple filetypes](https://stackoverflow.com/questions/4568580/python-glob-multiple-filetypes)

[How to loop with indexes in Python](https://treyhunner.com/2016/04/how-to-loop-with-indexes-in-python/)

[User input and command line arguments](https://stackoverflow.com/questions/70797/user-input-and-command-line-arguments)

[How to Rename File in Python? (with OS module)](https://favtutor.com/blogs/rename-file-python)

[How to rename a file using Python](https://stackoverflow.com/questions/2491222/how-to-rename-a-file-using-python)

[How to Check if a File Exists in Python with isFile() and exists()](https://www.freecodecamp.org/news/how-to-check-if-a-file-exists-in-python/)

[Extract file name from path, no matter what the os/path format](https://stackoverflow.com/questions/8384737/extract-file-name-from-path-no-matter-what-the-os-path-format)

[AttributeError: 'PosixPath' object has no attribute 'path'](https://stackoverflow.com/questions/59693174/attributeerror-posixpath-object-has-no-attribute-path)

[Convert JSON to dictionary in Python](https://www.geeksforgeeks.org/convert-json-to-dictionary-in-python/)

[Iterate through dictionary keys and values in Python](https://note.nkmk.me/en/python-dict-keys-values-items/)

[How to Run One Python Script From Another](https://datatofish.com/one-python-script-from-another/)

[How to call a script from another script?](https://stackoverflow.com/questions/1186789/how-to-call-a-script-from-another-script)

[python __pycache__的认识](https://blog.csdn.net/qq_44940689/article/details/123133515)

[python中gitignore使用](https://blog.51cto.com/u_16175438/6761229)
