## Determine whether a directory exists in Bash
```
➜  check-exists git:(master) sh check-dir-exists.sh TEST/ 
Determining whether a directory exists in Bash...
[DIR] TEST/ exists. 🎉
➜  check-exists git:(master) sh check-dir-exists.sh TEST 
Determining whether a directory exists in Bash...
[DIR] TEST exists. 🎉
➜  check-exists git:(master) ✗ sh check-dir-exists.sh Test
Determining whether a directory exists in Bash...
[DIR] Test exists. 🎉

➜  check-exists git:(master) ✗ sh check-dir-exists.sh /Users/xxx/Downloads/Shell-Collection/check-exists/TEST
Determining whether a directory exists in Bash...
[DIR] /Users/xxx/Downloads/Shell-Collection/check-exists/TEST exists. 🎉

➜  check-exists git:(master) ✗ sh check-dir-exists.sh TEST2
Determining whether a directory exists in Bash...
[DIR] TEST2 not exists! ❌
```

## Determine whether a file exists in Bash
➜  check-exists git:(master) ✗ sh check-file-exists.sh check-file-exists.sh 
Determining whether a file exists in Bash...
[FILE] check-file-exists.sh exists. 🎉
➜  check-exists git:(master) ✗ sh check-file-exists.sh Check-file-exists.sh
Determining whether a file exists in Bash...
[FILE] Check-file-exists.sh exists. 🎉

➜  check-exists git:(master) ✗ sh check-file-exists.sh /Users/xxx/Downloads/Shell-Collection/check-exists/README.md
Determining whether a file exists in Bash...
[FILE] /Users/xxx/Downloads/Shell-Collection/check-exists/README.md exists. 🎉

➜  check-exists git:(master) ✗ sh check-file-exists.sh check-file-exists2.sh    
Determining whether a file exists in Bash...
[FILE] check-file-exists2.sh not exists! ❌
