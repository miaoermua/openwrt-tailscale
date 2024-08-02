-- /usr/lib/lua/luci/model/cbi/tailscale/settings.lua
local m, s, o
local fs = require "nixio.fs"

m = Map("tailscale", translate("Tailscale"), translate("Tailscale 使创建软件定义网络变得简单：安全地连接用户、服务和设备。"))

m:section(SimpleSection).template = "shadowsocksr/status"
m.cfgvalue = function()
    local status = luci.sys.exec("/usr/sbin/tailscale status 2>/dev/null")
    if status == "" then
        status = "<span style='color: red;'>" .. translate("Tailscale 未运行") .. "</span>"
    else
        status = "<span style='color: green;'>" .. translate("Tailscale 运行中") .. "</span>"
    end
    return status
end

s = m:section(TypedSection, "config", translate("Tailscale Settings"))
s.anonymous = true
s.addremove = false

-- 启用选项
o = s:option(Flag, "enabled", translate("启用"))
o.rmempty = false

-- Tailscale 状态
o = s:option(DummyValue, "status", translate("Status"))
o.rawhtml = true
o.cfgvalue = function()
    local status = luci.sys.exec("/usr/sbin/tailscale status 2>/dev/null")
    if status == "" then
        status = "<span style='color: red;'>" .. translate("Tailscale 未运行") .. "</span>"
    else
        status = "<span style='color: green;'>" .. translate("Tailscale 运行中") .. "</span>"
    end
    return status
end

-- Tailscale Up 按钮
o = s:option(Button, "_up", translate("Tailscale Up"))
o.inputtitle = translate("Tailscale Up")
o.inputstyle = "apply"
o.write = function(self, section)
    local cmd = "tailscale up"
    if nodeexit:formvalue(section) == "1" then
        cmd = cmd .. " --advertise-exit-node"
    end
    if acceptroutes:formvalue(section) == "1" then
        cmd = cmd .. " --accept-routes"
    end
    local selected_route = advertiseroutes:formvalue(section)
    if selected_route and selected_route ~= "" and selected_route ~= "disabled" then
        if selected_route == "custom" then
            selected_route = customroute:formvalue(section)
        end
        cmd = cmd .. " --advertise-routes=" .. selected_route
    end
    luci.sys.call(cmd .. " >/dev/null 2>&1 &")
end

-- Tailscale 管理页面链接
o = s:option(DummyValue, "management_page", translate("Tailscale Web"))
o.rawhtml = true
o.cfgvalue = function()
    local url = "https://login.tailscale.com/admin/machines"
    return "<a href='" .. url .. "' target='_blank' class='cbi-button cbi-button-apply'>" .. translate("Manage devices") .. "</a>"
end
o.description = translate("如果你需要长期使用，确保在管理页面中禁用 'Enabled key expiry'，到期后会退出登录。")

-- 日志
o = s:option(DummyValue, "logs", translate("Tailscale Output"))
o.rawhtml = true
o.cfgvalue = function()
    local output = luci.sys.exec("/usr/sbin/tailscale status 2>/dev/null")
    local logs = output:gsub("\n", "<br>")
    local loginUrl = output:match("(https://login%.tailscale%.com/%S+)")
    if loginUrl then
        logs = logs .. "<br><a href='" .. loginUrl .. "' target='_blank' class='cbi-button cbi-button-apply'>" .. translate("Login to Tailscale") .. "</a>"
    end
    return "<div style='padding: 10px; border: 1px solid #ccc; border-radius: 4px;'>" .. logs .. "</div>"
end
o.description = translate("登录后显示设备信息，没登录会显示登录链接以开始绑定")

-- Advertise as exit node 选项
local nodeexit = s:option(Flag, "nodeexit", translate("Exit node"))
nodeexit.rmempty = false
nodeexit.description = translate("勾选后可以使 Tailscale 网络中的设备直接作为 VPN 出口访问到你的网络.")

-- Accept routes from peers 选项
local acceptroutes = s:option(Flag, "acceptroutes", translate("Accept routes"))
acceptroutes.rmempty = false
acceptroutes.description = translate("勾选后可以使 Tailscale 网络中的设备访问到你的设备.")
acceptroutes.write = function(self, section, value)
    if value == "1" then
        luci.http.redirect(luci.dispatcher.build_url("admin/services/tailscale"))
    end
    return Flag.write(self, section, value)
end

-- Advertise routes 选项
local advertiseroutes = s:option(ListValue, "advertiseroutes", translate("Subnet routes"))
advertiseroutes:value("disabled", translate("Disabled"))
advertiseroutes:value("custom", translate("Custom"))
advertiseroutes:value("10.0.0.0/24", "10.0.0.0/24")
advertiseroutes:value("192.168.0.0/24", "192.168.0.0/24")
advertiseroutes:value("172.16.0.0/12", "172.16.0.0/12")
advertiseroutes.description = translate("将本地子网添加到 Tailscale 网络中, 允许 Tailscale 用户访问该子网中的设备.")

-- 自定义路由输入框，仅在选择“自定义”时显示
local customroute = s:option(Value, "customroute", translate("Custom route"))
customroute:depends("advertiseroutes", "custom")
customroute.placeholder = "10.0.0.0/24"

-- 检查并显示“添加 ts 接口”按钮
local ifexists = luci.sys.exec("uci show network | grep -q 'tailscale=' && echo '1' || echo '0'")
if ifexists == "0" then
    local addif = s:option(Button, "add_interface", translate("添加 ts 接口"))
    addif.inputtitle = translate("Add ts interface")
    addif.inputstyle = "apply"
    addif.write = function(self, section)
        local ip = luci.sys.exec("ip addr show tailscale0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1"):match("^%s*(.-)%s*$")
        if not ip or ip == "" then
            ip = "100.94.67.7"
        end
        luci.sys.call("uci set network.tailscale=interface")
        luci.sys.call("uci set network.tailscale.ifname='tailscale0'")
        luci.sys.call("uci set network.tailscale.ipaddr='" .. ip .. "'")
        luci.sys.call("uci set network.tailscale.netmask='255.0.0.0'")
        luci.sys.call("uci set network.tailscale.proto='static'")
        luci.sys.call("uci commit network")
        luci.sys.call("/etc/init.d/network reload")
    end
    addif:depends("acceptroutes", "1")
end

return m
