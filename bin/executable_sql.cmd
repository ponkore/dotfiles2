@echo off
rem ---- SQLcl wrapper (scoop): suppress JLine warnings + fix console mojibake ----
chcp 65001 >nul
setlocal
set "SQLCL=C:\Users\masao\scoop\apps\sqlcl\current"
set "CP=%SQLCL%\lib\*;%SQLCL%\lib\ext\*;%SQLCL%\lib\drivers\*;%SQLCL%\lib\sdks\aws\*;%SQLCL%\lib\sdks\jdbc-oci\*;%SQLCL%\lib\sdks\jdbc-azure\*;%SQLCL%\lib\ext\pgql\*"
java -client -XX:+IgnoreUnrecognizedVMOptions ^
  --enable-native-access=ALL-UNNAMED ^
  --enable-final-field-mutation=ALL-UNNAMED ^
  --add-opens=java.prefs/java.util.prefs=ALL-UNNAMED ^
  --add-opens=java.base/java.lang=ALL-UNNAMED ^
  -Xms64M -Xss100M -Xmx2G ^
  -Dfile.encoding=UTF-8 ^
  -Dcore.secureRandom=SHA1PRNG ^
  -Dsqlcl.bin="%SQLCL%\bin" ^
  -Djava.net.useSystemProxies=true ^
  -cp "%CP%" ^
  oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli %*
endlocal
