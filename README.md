# command-qq
[![Build Status](https://secure.travis-ci.org/biegunka/command-qq.png?branch=master)](http://travis-ci.org/biegunka/command-qq)
[![Build Status](https://drone.io/github.com/biegunka/command-qq/status.png)](https://drone.io/github.com/biegunka/command-qq/latest)

```
>>> import System.Command.QQ
>>> putStrLn =<< unlines . reverse . lines <$> [sh|cowsay "Hello, I am command-qq!"|]
                ||     ||
                ||----w |
            (__)\       )\/\
         \  (oo)\_______
        \   ^__^
 -------------------------
< Hello, I am command-qq! >
 _________________________
```
