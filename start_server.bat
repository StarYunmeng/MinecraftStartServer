::✂---------------------------------------------------------------------------------------------------------------------------------------------------------------
@echo off
:: 启用变量延迟扩展
setlocal enabledelayedexpansion
:: 简易Minecraft服务器启动器 - 自动内存检测
:: 作者: 星云梦 mcscd.cn

:: 设置自动重启标志
set "AUTO_RESTART=true"

:: 启用ANSI颜色支持 (Windows 10+)
reg query HKCU\Console /v VirtualTerminalLevel >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=3" %%a in ('reg query HKCU\Console /v VirtualTerminalLevel') do (
        if %%a EQU 0 (
            reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul
        )
    )
) else (
    reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul
)

:: 定义ANSI转义字符 (使用可靠的方法生成ESC字符)
for /f "delims=#" %%i in ('prompt #$E#^&echo on^&for %%a in ^(1^) do rem') do set "ESC=%%i"

:: 设置代码页为UTF-8以支持中文显示
chcp 65001 > nul

:: 检查配置文件是否存在
if exist "start_config.scd" (
    :: 加载配置文件中的变量
    for /f "usebackq tokens=*" %%a in ("start_config.scd") do (
        %%a
    )
    goto :LOAD_JVM_ARGS
) else (
    echo 配置文件不存在，创建新配置...
    goto :CREATE_CONFIG
)

:: 没有配置文件，创建新配置
:CREATE_CONFIG
cls
echo ===================================================
echo             MINECRAFT服务器自动启动器            
echo ===================================================
echo.

echo 步骤1: 正在检测系统内存...

:: 使用PowerShell获取系统总内存
for /f "usebackq delims=" %%a in (`powershell -command "[math]::floor((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1MB)"`) do set SYSTEM_MEMORY_MB=%%a

:: 如果检测失败，默认设置为16GB
if %SYSTEM_MEMORY_MB% EQU 0 set SYSTEM_MEMORY_MB=16384

echo 检测到的系统内存: %SYSTEM_MEMORY_MB% MB

echo 步骤2: 计算推荐内存 (系统内存的80%%)...
set /a RECOMMENDED_MEMORY_MB=%SYSTEM_MEMORY_MB% * 80 / 100
set /a MIN_MEMORY_GB=%RECOMMENDED_MEMORY_MB% * 70 / 102400
set /a MAX_MEMORY_GB=%RECOMMENDED_MEMORY_MB% / 1024

:: 确保最小内存为2GB
if %MIN_MEMORY_GB% LSS 2 set MIN_MEMORY_GB=2
if %MAX_MEMORY_GB% LSS 2 set MAX_MEMORY_GB=2

set MIN_MEMORY=%MIN_MEMORY_GB%G
set MAX_MEMORY=%MAX_MEMORY_GB%G

echo 推荐内存: %MIN_MEMORY% - %MAX_MEMORY%
echo.

echo 步骤3: 选择服务器类型:
echo.
echo ║1. Vanilla（原版）"
echo ║2. Paper（高性能）"
echo ║3. Folia（多线程支持）"
echo ║4. Spigot（插件支持）"
echo ║%ESC%[36m5. Geyser（跨平台支持）%ESC%[0m"
echo "6. BungeeCord&Velocity（跨区域支持）
echo.

:CHOOSE_SERVER_TYPE
echo 请输入选项 (1-6): 
set /p SERVER_TYPE_OPT=

if "%SERVER_TYPE_OPT%"=="1" set SERVER_TYPE=vanilla
if "%SERVER_TYPE_OPT%"=="2" set SERVER_TYPE=paper
if "%SERVER_TYPE_OPT%"=="3" set SERVER_TYPE=folia
if "%SERVER_TYPE_OPT%"=="4" set SERVER_TYPE=spigot
if "%SERVER_TYPE_OPT%"=="5" set SERVER_TYPE=geyser
if "%SERVER_TYPE_OPT%"=="6" (
    echo.
    echo 请选择代理服务器类型:
    echo a. BungeeCord
    echo b. Velocity
    set /p PROXY_TYPE=
    if "!PROXY_TYPE!"=="a" set SERVER_TYPE=bungeecord
    if "!PROXY_TYPE!"=="b" set SERVER_TYPE=velocity
    if not defined SERVER_TYPE (
        echo 无效的选项！默认使用BungeeCord。
        set SERVER_TYPE=bungeecord
    )
)

if not defined SERVER_TYPE (
    echo 无效的选项！请重新输入。
    goto :CHOOSE_SERVER_TYPE
)

echo.
echo 步骤4: 请输入服务器JAR文件名

:: 查找当前目录下最大的.jar文件
set "JAR_FOUND=false"
set "LARGEST_JAR=server.jar"
set "LARGEST_SIZE=0"

:: 检查是否有任何.jar文件存在
for %%F in (*.jar) do (
    set "JAR_FOUND=true"
    goto :CHECK_JAR_SIZES
)

:CHECK_JAR_SIZES
if "!JAR_FOUND!"=="true" (
    for %%F in (*.jar) do (
        for /f "usebackq" %%S in ('powershell -command "(Get-Item '%%F').Length"') do (
            if %%S GTR !LARGEST_SIZE! (
                set "LARGEST_SIZE=%%S"
                set "LARGEST_JAR=%%F"
            )
        )
    )
) else (
    echo 未找到JAR文件，请输入服务端的名字: （默认:server.jar）
)

echo 请输入服务端的名字 (直接回车将采用自动获取到的: !LARGEST_JAR!): 
set /p SERVER_JAR=
if not defined SERVER_JAR set SERVER_JAR=!LARGEST_JAR!

echo.
echo 步骤5: 请输入预计玩家数量 (默认: 20): 
set /p PLAYER_COUNT=
if not defined PLAYER_COUNT set PLAYER_COUNT=20

echo.
echo 正在根据服务器类型和玩家数量优化内存设置...

:: 根据服务器类型和玩家数量设置合理内存
if "%SERVER_TYPE%"=="vanilla" (
    :: Vanilla服务器 - 基础2GB + 每玩家0.15GB
    set /a MIN_MEMORY_GB=2 + %PLAYER_COUNT% * 15 / 100
    set /a MAX_MEMORY_GB=3 + %PLAYER_COUNT% * 25 / 100
    if !MIN_MEMORY_GB! GTR 8 set MIN_MEMORY_GB=8
    if !MAX_MEMORY_GB! GTR 16 set MAX_MEMORY_GB=16
    echo 已优化Vanilla服务器内存设置: !MIN_MEMORY_GB!G - !MAX_MEMORY_GB!G
) else if "%SERVER_TYPE%"=="paper" (
    :: Paper服务器 - 基础3GB + 每玩家0.2GB
    set /a MIN_MEMORY_GB=3 + %PLAYER_COUNT% * 20 / 100
    set /a MAX_MEMORY_GB=4 + %PLAYER_COUNT% * 30 / 100
    if !MIN_MEMORY_GB! GTR 10 set MIN_MEMORY_GB=10
    if !MAX_MEMORY_GB! GTR 20 set MAX_MEMORY_GB=20
    echo 已优化Paper服务器内存设置: !MIN_MEMORY_GB!G - !MAX_MEMORY_GB!G
) else if "%SERVER_TYPE%"=="folia" (
    :: Folia服务器 - 基础3GB + 每玩家0.25GB (多线程更耗内存)
    set /a MIN_MEMORY_GB=3 + %PLAYER_COUNT% * 25 / 100
    set /a MAX_MEMORY_GB=5 + %PLAYER_COUNT% * 35 / 100
    if !MIN_MEMORY_GB! GTR 12 set MIN_MEMORY_GB=12
    if !MAX_MEMORY_GB! GTR 24 set MAX_MEMORY_GB=24
    echo 已优化Folia服务器内存设置: !MIN_MEMORY_GB!G - !MAX_MEMORY_GB!G
) else if "%SERVER_TYPE%"=="spigot" (
    :: Spigot服务器 - 基础2.5GB + 每玩家0.18GB
    set /a MIN_MEMORY_GB=2 + %PLAYER_COUNT% * 18 / 100
    set /a MAX_MEMORY_GB=3 + %PLAYER_COUNT% * 28 / 100
    if !MIN_MEMORY_GB! GTR 8 set MIN_MEMORY_GB=8
    if !MAX_MEMORY_GB! GTR 16 set MAX_MEMORY_GB=16
    echo 已优化Spigot服务器内存设置: !MIN_MEMORY_GB!G - !MAX_MEMORY_GB!G
) else if "%SERVER_TYPE%"=="geyser" (
    :: Geyser服务器 - 基础1GB + 每玩家0.1GB
    set /a MIN_MEMORY_GB=1 + %PLAYER_COUNT% * 10 / 100
    set /a MAX_MEMORY_GB=2 + %PLAYER_COUNT% * 15 / 100
    if !MIN_MEMORY_GB! GTR 4 set MIN_MEMORY_GB=4
    if !MAX_MEMORY_GB! GTR 8 set MAX_MEMORY_GB=8
    echo 已优化Geyser服务器内存设置: !MIN_MEMORY_GB!G - !MAX_MEMORY_GB!G
) else if "%SERVER_TYPE%"=="bungeecord" (
    :: BungeeCord服务器 - 基础1GB + 每玩家0.08GB
    set /a MIN_MEMORY_GB=1 + %PLAYER_COUNT% * 8 / 100
    set /a MAX_MEMORY_GB=2 + %PLAYER_COUNT% * 12 / 100
    if !MIN_MEMORY_GB! GTR 3 set MIN_MEMORY_GB=3
    if !MAX_MEMORY_GB! GTR 6 set MAX_MEMORY_GB=6
    echo 已优化BungeeCord服务器内存设置: !MIN_MEMORY_GB!G - !MAX_MEMORY_GB!G
) else if "%SERVER_TYPE%"=="velocity" (
    :: Velocity服务器 - 基础1GB + 每玩家0.09GB
    set /a MIN_MEMORY_GB=1 + %PLAYER_COUNT% * 9 / 100
    set /a MAX_MEMORY_GB=2 + %PLAYER_COUNT% * 14 / 100
    if !MIN_MEMORY_GB! GTR 3 set MIN_MEMORY_GB=3
    if !MAX_MEMORY_GB! GTR 6 set MAX_MEMORY_GB=6
    echo 已优化Velocity服务器内存设置: !MIN_MEMORY_GB!G - !MAX_MEMORY_GB!G
)

set MIN_MEMORY=%MIN_MEMORY_GB%G
set MAX_MEMORY=%MAX_MEMORY_GB%G

echo.
echo 步骤6: 选择Java执行方式
echo 请选择Java执行方式 (直接回车=自动 或 手动指定Java路径例如：C:\Program Files\Java\jdk-17\bin\java.exe): 
set /p JAVA_PATH=
if not defined JAVA_PATH set JAVA_PATH=java

echo.
echo 正在保存配置...
>"start_config.scd" echo set "MIN_MEMORY=%MIN_MEMORY%"
>>"start_config.scd" echo set "MAX_MEMORY=%MAX_MEMORY%"
>>"start_config.scd" echo set "SERVER_TYPE=%SERVER_TYPE%"
>>"start_config.scd" echo set "SERVER_JAR=%SERVER_JAR%"
>>"start_config.scd" echo set "PLAYER_COUNT=%PLAYER_COUNT%"
>>"start_config.scd" echo set "JAVA_PATH=%JAVA_PATH%"

:: 生成JVM参数
echo 正在根据服务器类型和玩家数量生成JVM参数...
set "JVM_ARGS=-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200"
set "JVM_ARGS=%JVM_ARGS% -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch"

:: 根据玩家数量调整GC参数
echo 根据玩家数量优化GC参数...
if %PLAYER_COUNT% LSS 10 (
    :: 小型服务器（1-9名玩家）
    set "JVM_ARGS=%JVM_ARGS% -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=15"
    echo 应用小型服务器优化参数
) else if %PLAYER_COUNT% LSS 30 (
    :: 中型服务器（10-29名玩家）
    set "JVM_ARGS=%JVM_ARGS% -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:ConcGCThreads=2"
    echo 应用中型服务器优化参数
) else if %PLAYER_COUNT% LSS 60 (
    :: 大型服务器（30-59名玩家）
    set "JVM_ARGS=%JVM_ARGS% -XX:G1HeapRegionSize=32M -XX:G1ReservePercent=25 -XX:ConcGCThreads=3"
    echo 应用大型服务器优化参数
) else (
    :: 超大型服务器（60名以上玩家）
    set "JVM_ARGS=%JVM_ARGS% -XX:G1HeapRegionSize=32M -XX:G1ReservePercent=30 -XX:ConcGCThreads=4 -XX:G1RSetUpdatingPauseTimePercent=5"
    echo 应用超大型服务器优化参数
)

:: Initialize thread variables
set "CPU_COUNT=%NUMBER_OF_PROCESSORS%"
set WORKER_THREADS=%CPU_COUNT%
set WORLD_THREADS=%CPU_COUNT%

:: Add server type specific parameters
if "%SERVER_TYPE%"=="folia" (
    :: Use system environment variable to get CPU count (more reliable)
    echo 检测到CPU核心数: %CPU_COUNT%
    set /a WORKER_THREADS=%CPU_COUNT% * 2 / 3
    set /a WORLD_THREADS=%CPU_COUNT% * 1 / 3
    if %WORKER_THREADS% LSS 2 set WORKER_THREADS=2
    if %WORLD_THREADS% LSS 2 set WORLD_THREADS=2
    set "JVM_ARGS=%JVM_ARGS% -Dpaperworker.threads=!WORKER_THREADS! -Dpaperworld.threads=!WORLD_THREADS!"
    echo 已添加Folia线程优化
) else if "%SERVER_TYPE%"=="paper" (
    set "JVM_ARGS=!JVM_ARGS! -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=16M"
    echo 已添加Paper优化
) else if "%SERVER_TYPE%"=="spigot" (
    set "JVM_ARGS=!JVM_ARGS! -XX:G1NewSizePercent=20 -XX:G1MaxNewSizePercent=30 -XX:G1HeapRegionSize=8M"
    echo 已添加Spigot优化
) else if "%SERVER_TYPE%"=="geyser" (
    set "JVM_ARGS=!JVM_ARGS! -Dgeyser.dump-packets=false -Dgeyser.debug-mode=false"
    echo 已添加Geyser优化
) else if "%SERVER_TYPE%"=="bungeecord" (
    set "JVM_ARGS=!JVM_ARGS! -XX:G1NewSizePercent=20 -XX:G1MaxNewSizePercent=30 -XX:G1HeapRegionSize=4M"
    set "JVM_ARGS=!JVM_ARGS! -Dnet.md_5.bungee.log=INFO"
    echo 已添加BungeeCord优化
) else if "%SERVER_TYPE%"=="velocity" (
    set "JVM_ARGS=!JVM_ARGS! -XX:G1NewSizePercent=25 -XX:G1MaxNewSizePercent=35 -XX:G1HeapRegionSize=8M"
    set "JVM_ARGS=!JVM_ARGS! -Dvelocity.log.level=INFO -Dvelocity.native-transport=true"
    echo 已添加Velocity优化
)

:: 添加玩家数量特定的网络优化参数
if %PLAYER_COUNT% GTR 20 (
    set "JVM_ARGS=%JVM_ARGS% -Dentity-tracking-range=48 -Dview-distance=10"
    echo 已添加大型服务器网络优化参数
)

:: 保存JVM参数和线程设置到配置文件
>>"start_config.scd" echo set "JVM_ARGS=%JVM_ARGS%"
>>"start_config.scd" echo set "WORKER_THREADS=%WORKER_THREADS%"
>>"start_config.scd" echo set "WORLD_THREADS=%WORLD_THREADS%"

echo. 
echo 配置已准备就绪，即将启动服务器...

:: 仅在需要EULA的服务器类型上自动生成并同意EULA协议 
if "%SERVER_TYPE%"=="vanilla" (
    echo eula=true > eula.txt
    echo 已自动生成eula.txt文件并同意协议
) else if "%SERVER_TYPE%"=="paper" (
    echo eula=true > eula.txt
    echo 已自动生成eula.txt文件并同意协议
) else if "%SERVER_TYPE%"=="folia" (
    echo eula=true > eula.txt
    echo 已自动生成eula.txt文件并同意协议
) else if "%SERVER_TYPE%"=="spigot" (
    echo eula=true > eula.txt
    echo 已自动生成eula.txt文件并同意协议
) else (
    echo 当前服务器类型不需要EULA协议~喵~
)
timeout /t 2 /nobreak >nul 
start "" "%~dpnx0" 
exit
::✂---------------------------------------------------------------------------------------------------------------------------------------------------------------
:: 从配置文件加载后设置JVM参数
:LOAD_JVM_ARGS

setlocal enabledelayedexpansion
:: 先移除JVM_ARGS中的内存设置，避免重复添加
set "TEMP_JVM_ARGS=!JVM_ARGS!"
:: 再添加正确的内存设置
set "TEMP_JVM_ARGS=-Xms%MIN_MEMORY% -Xmx%MAX_MEMORY% !TEMP_JVM_ARGS!"
endlocal & set "JVM_ARGS=%TEMP_JVM_ARGS%"

:: 可爱的像素风格STAR CLOUD DREAM标题（彩色）
echo. %ESC%[36m╔════════════════════════════════════════════════════╗%ESC%[0m
echo. %ESC%[36m║                                                      %ESC%[0m
echo. %ESC%[36m║                               %ESC%[38;2;163;248;65m███████╗████████╗ █████╗ ██████╗                   
echo. %ESC%[36m║                               %ESC%[38;2;163;248;65m██╔════╝╚══██╔══╝██╔══██╗██╔══██╗                
echo. %ESC%[36m║                               %ESC%[38;2;163;248;65m███████╗   ██║   ███████║██████╔╝               
echo. %ESC%[36m║                               %ESC%[38;2;163;248;65m╚════██║   ██║   ██╔══██║██╔══██╗                
echo. %ESC%[36m║                               %ESC%[38;2;163;248;65m███████║   ██║   ██║  ██║██║  ██║                
echo. %ESC%[36m║                               %ESC%[38;2;163;248;65m╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝               
echo. %ESC%[36m║                                                  
echo. %ESC%[36m║  %ESC%[38;2;163;248;65m ██████╗██╗      ██████╗ ██╗   ██╗██████╗     ██████╗ ██████╗ ███████╗ █████╗ ███╗   ███╗ 
echo. %ESC%[36m║  %ESC%[38;2;163;248;65m██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗    ██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗ ████║  
echo. %ESC%[36m║  %ESC%[38;2;163;248;65m██║     ██║     ██║   ██║██║   ██║██║  ██║    ██║  ██║██████╔╝█████╗  ███████║██╔████╔██║ 
echo. %ESC%[36m║  %ESC%[38;2;163;248;65m██║     ██║     ██║   ██║██║   ██║██║  ██║    ██║  ██║██╔══██╗██╔══╝  ██╔══██║██║╚██╔╝██║ 
echo. %ESC%[36m║  %ESC%[38;2;163;248;65m╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝    ██████╔╝██║  ██║███████╗██║  ██║██║ ╚═╝ ██║ 
echo. %ESC%[36m║  %ESC%[38;2;163;248;65m ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝     ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ 
echo. %ESC%[36m║ %ESC%[0m
echo. %ESC%[36m║ %ESC%[0m
echo. %ESC%[36m║                             %ESC%[33m★ %ESC%[0m内存：%ESC%[33m%MIN_MEMORY% - %MAX_MEMORY%        %ESC%[1;31m♥ %ESC%[0m工作线程：%ESC%[1;31m%WORKER_THREADS%%ESC%[0m
echo. %ESC%[36m║             %ESC%[0m—————————————————————————————————————————————————————————————————————%ESC%[0m
echo. %ESC%[36m║                            %ESC%[0m☠  语言：%ESC%[37m中文%ESC%[0m            %ESC%[31m⛏  %ESC%[0m世界线程：%ESC%[33m%WORLD_THREADS%%ESC%[0m
echo. %ESC%[36m║  
echo. %ESC%[36m║ %ESC%[1m%ESC%[38;2;163;248;65m                             ♥ 阁下云梦正在为您创建世界中稍等 ♥                          %ESC%[0m
echo. %ESC%[36m║  
echo. %ESC%[36m╚════════════════════════════════════════════════════╝%ESC%[0m
echo.

:RESTART_LOOP
echo %ESC%[36m[Now Loading]%ESC%[0m 少女祈祷中，请稍候...
echo.
:: 启动服务器
echo %JAVA_PATH% %JVM_ARGS% -jar "%SERVER_JAR%" nogui

:: 检查退出代码
if not errorlevel 1 (
    :: 正常退出
    echo=%ESC%[32m[正常关闭]%ESC%[0m 服务器已优雅关闭，感谢使用云梦的Minecraft启动器~喵~
    goto END
) else (
    :: 非正常退出且自动重启功能开启时
    if "%AUTO_RESTART%" EQU "true" (
        echo %ESC%[31m[异常关闭]%ESC%[0m 服务器意外关闭，将在5秒后自动重启...
        timeout /t 5 /nobreak >nul
        goto RESTART_LOOP
    ) else (
        echo %ESC%[31m[异常关闭]%ESC%[0m 服务器意外关闭
    )
)

:END
echo %ESC%[35m[结束]%ESC%[0m 服务器已停止运行，按任意键退出...
pause >nul
endlocal
::✂---------------------------------------------------------------------------------------------------------------------------------------------------------------