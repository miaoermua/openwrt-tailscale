-- /usr/lib/lua/luci/controller/tailscale.lua
module("luci.controller.tailscale", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/tailscale") then
        return
    end

    entry({"admin", "services", "tailscale"}, alias("admin", "services", "tailscale", "settings"), _("Tailscale"), 10).dependent = true
    entry({"admin", "services", "tailscale", "settings"}, cbi("tailscale/settings"), _("Settings"), 1).leaf = true
end
