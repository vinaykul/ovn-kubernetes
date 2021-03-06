// +build linux

package util

import (
	"fmt"
	"os"
	"strings"
	"syscall"

	"github.com/sirupsen/logrus"
	"github.com/vishvananda/netlink"
)

func getBridgeName(iface string) string {
	return fmt.Sprintf("br%s", iface)
}

func saveIPAddress(iface, bridge netlink.Link, addrs []netlink.Addr) error {
	for i := range addrs {
		addr := addrs[i]

		// Remove from old interface
		if err := netlink.AddrDel(iface, &addr); err != nil {
			logrus.Errorf("Remove addr from %q failed: %v", iface.Attrs().Name, err)
			return err
		}

		// Add to ovs bridge
		addr.Label = bridge.Attrs().Name
		if err := netlink.AddrAdd(bridge, &addr); err != nil {
			logrus.Errorf("Add addr to bridge %q failed: %v", bridge.Attrs().Name, err)
			return err
		}
		logrus.Infof("Successfully saved addr %q to bridge %q", addr.String(), bridge.Attrs().Name)
	}

	return netlink.LinkSetUp(bridge)
}

// delAddRoute removes 'route' from 'iface' and moves to 'bridge'
func delAddRoute(iface, bridge netlink.Link, route netlink.Route) error {
	// Remove route from old interface
	if err := netlink.RouteDel(&route); err != nil && !strings.Contains(err.Error(), "no such process") {
		logrus.Errorf("Remove route from %q failed: %v", iface.Attrs().Name, err)
		return err
	}

	// Add route to ovs bridge
	route.LinkIndex = bridge.Attrs().Index
	if err := netlink.RouteAdd(&route); err != nil && !os.IsExist(err) {
		logrus.Errorf("Add route to bridge %q failed: %v", bridge.Attrs().Name, err)
		return err
	}

	logrus.Infof("Successfully saved route %q", route.String())
	return nil
}

func saveRoute(iface, bridge netlink.Link, routes []netlink.Route) error {
	for i := range routes {
		route := routes[i]

		// Handle routes for default gateway later.  This is a special case for
		// GCE where we have /32 IP addresses and we can't add the default
		// gateway before the route to the gateway.
		if route.Dst == nil && route.Gw != nil && route.LinkIndex > 0 {
			continue
		}

		err := delAddRoute(iface, bridge, route)
		if err != nil {
			return err
		}
	}

	// Now add the default gateway (if any) via this interface.
	for i := range routes {
		route := routes[i]
		if route.Dst == nil && route.Gw != nil && route.LinkIndex > 0 {
			// Remove route from 'iface' and move it to 'bridge'
			err := delAddRoute(iface, bridge, route)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

// NicToBridge creates a OVS bridge for the 'iface' and also moves the IP
// address and routes of 'iface' to OVS bridge.
func NicToBridge(iface string) error {
	ifaceLink, err := netlink.LinkByName(iface)
	if err != nil {
		return err
	}

	bridge := getBridgeName(iface)
	stdout, stderr, err := RunOVSVsctl(
		"--", "--may-exist", "add-br", bridge,
		"--", "br-set-external-id", bridge, "bridge-id", bridge,
		"--", "set", "bridge", bridge, "fail-mode=standalone",
		fmt.Sprintf("other_config:hwaddr=%s", ifaceLink.Attrs().HardwareAddr),
		"--", "--may-exist", "add-port", bridge, iface)
	if err != nil {
		logrus.Errorf("Failed to create OVS bridge, stdout: %q, stderr: %q, error: %v", stdout, stderr, err)
		return err
	}
	logrus.Infof("Successfully created OVS bridge %q", bridge)

	// Get ip addresses and routes before any real operations.
	addrs, err := netlink.AddrList(ifaceLink, syscall.AF_INET)
	if err != nil {
		return err
	}
	routes, err := netlink.RouteList(ifaceLink, syscall.AF_INET)
	if err != nil {
		return err
	}

	bridgeLink, err := netlink.LinkByName(bridge)
	if err != nil {
		return err
	}

	// save ip addresses to bridge.
	if err = saveIPAddress(ifaceLink, bridgeLink, addrs); err != nil {
		return err
	}

	// save routes to bridge.
	if err = saveRoute(ifaceLink, bridgeLink, routes); err != nil {
		return err
	}

	return nil
}
