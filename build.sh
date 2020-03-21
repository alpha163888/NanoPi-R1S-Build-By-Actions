#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#!/bin/bash
#记录开始时间
start_time=`date --date='0 days ago' "+%Y-%m-%d %H:%M:%S"`
#初始化
git config --local user.email "action@github.com" && git config --local user.name "GitHub Action"
git clone https://github.com/alpha163888/NanoPi-R1S-Build-By-Actions.git
cd NanoPi-R1S-Build-By-Actions
chmod 777 ./remove_unused_config.sh
git clone https://github.com/friendlyarm/repo
sudo cp repo/repo /usr/bin/
#下载源码
mkdir friendlywrt-h5
cd friendlywrt-h5
repo init -u https://github.com/friendlyarm/friendlywrt_manifests -b master-v19.07.1 -m h5.xml --repo-url=https://github.com/friendlyarm/repo  --no-clone-bundle
repo sync -c --no-clone-bundle -j8
#合并OpenWrt代码
. ../remove_unused_config.sh
cat ../app_config.seed >> configs/config_h5
echo '# CONFIG_V2RAY_COMPRESS_UPX is not set' >> configs/config_h5
sed -i '/docker/Id;/containerd/Id;/runc/Id;/iptparser/Id' configs/config_h5 #fix compile error
cd friendlywrt
git config --local user.email "action@github.com" && git config --local user.name "GitHub Action"
git remote add upstream https://github.com/coolsnowwolf/lede && git fetch upstream
git rebase 90bb1cf9c33e73de5019686b8bd495f689e675a4^ --onto upstream/master -X theirs
git checkout upstream/master -- feeds.conf.default
cd package/lean/
rm -rf luci-theme-argon
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git
cd ../../
sed -i '/exit/i\mv /etc/rc.d/S25dockerd /etc/rc.d/S92dockerd && sed -i "s/START=25/START=92/g" S92dockerd' package/lean/default-settings/files/zzz-default-settings
sed -i '/uci commit luci/i\uci set luci.main.mediaurlbase="/luci-static/argon"' package/lean/default-settings/files/zzz-default-settings
sed -i '/exit/i\chown -R root:root /usr/share/netdata/web' package/lean/default-settings/files/zzz-default-settings
sed -i 's/option fullcone\t1/option fullcone\t0/' package/network/config/firewall/files/firewall.config
sed -i '/8.8.8.8/d' package/base-files/files/root/setup.sh
echo -e '\nDYC Build\n'  >> package/base-files/files/etc/banner
#Mod luci
./scripts/feeds update -a && ./scripts/feeds install -a
sed -i '/Load Average/i\<tr><td width="33%"><%:CPU Temperature%></td><td><%=luci.sys.exec("cut -c1-2 /sys/class/thermal/thermal_zone0/temp")%></td></tr>' feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index.htm
sed -i 's/pcdata(boardinfo.system or "?")/"ARMv8"/' feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index.htm
#编译 OpenWrt
cd ..
cp configs/config_h5 friendlywrt/.config
cd friendlywrt
make defconfig && make download -j8
make -s -j$(nproc) || make V=s -j1
#Build SD img
cd ..
sed -i '130,150 {/build_friendlywrt/d}' scripts/build.sh
./build.sh nanopi_r1s.mk
#记录结束时间
finish_time=`date --date='0 days ago' "+%Y-%m-%d %H:%M:%S"`
duration=$(($(($(date +%s -d "$finish_time")-$(date +%s -d "$start_time")))))
echo "执行了 : $duration 秒"