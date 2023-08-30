# Recursively find and replace string in files by python

## Prepare

For those using Python 3.5+ you can now use a glob recursively with the use of ** and the recursive flag.

`replace.py` replacing 'Hello' with 'Hi' for all .txt files.

`replace_ios.py` replacing 'Hello' with 'Hi' for all iOS relative files(`*.{h,m,mm,xib,storyboard,swift}`).

`rename_oc_class_name.py` rename Objective-C class name

## Usage
`python3 replace.py`

`python3 replace_ios.py`

`python3 rename_oc_class_name.py`

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

## Reference

[Recursively find and replace string in text files](https://stackoverflow.com/questions/4205854/recursively-find-and-replace-string-in-text-files)

[Python glob multiple filetypes](https://stackoverflow.com/questions/4568580/python-glob-multiple-filetypes)

[How to loop with indexes in Python](https://treyhunner.com/2016/04/how-to-loop-with-indexes-in-python/)

[User input and command line arguments](https://stackoverflow.com/questions/70797/user-input-and-command-line-arguments)
