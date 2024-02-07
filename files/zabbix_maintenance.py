#!/usr/bin/env python3
"""This script is intended to run as a systemd timer or via a git post-recive hook.  It will search
a repository of yaml files.  with each file represending a node in zabbix.  The scriipt expects to
find a structure like the following in the file
    ```yaml
    status:
        operational: true
        ticket: null
    ```
Every nodes that is marked as operational: false will be added to a maintenance window in zabbix to
stop it alerting
"""

import logging
import re

from argparse import ArgumentParser, Namespace
from pathlib import Path
from time import time
from typing import Dict, List, Optional, Union

from pyzabbix import ZabbixAPI  # type: ignore

import yaml


logger = logging.getLogger(__name__)


class ZabbixMaintError(Exception):
    """Exception thrown from Config class."""


# pylint: disable=too-many-instance-attributes
class ZabbixMaint:
    """Class to represent the config data"""

    def __init__(
        self,
        args: Namespace,
        maintenance_name: str,
        time_period: int = 31536000,
        fqdn_filter: Optional[str] = None,
    ) -> None:
        """The init class.

        We combine the config file and arguments together with the later taking precedence.

        Arguments:
            args: the arguments
            maintenance_name: The name to use for the maintenance
            time_period: The time period to use when creating the maintenance

        """
        if not args.config_file.is_file():
            raise ZabbixMaintError(f"{args.config_file}: dose not exist")

        self._args = args
        self._filter = fqdn_filter
        self._time_period = time_period
        self._config_file = args.config_file
        self.maintenance_name = maintenance_name
        try:
            self._yaml_data = yaml.safe_load(self._config_file.read_text())
        except yaml.scanner.ScannerError as error:
            raise ZabbixMaintError(
                f"Unable to parse yaml: {self._config_file}."
            ) from error

        self._server = str(self._get_config("server"))
        self._username = str(self._get_config("username"))
        self._password = str(self._get_config("password"))
        self._repo = Path(self._get_config("repo"))

        if not self._repo.is_dir():
            raise ZabbixMaintError(f"{self._repo}: dose not exist")

        self._zapi = ZabbixAPI(self._server)
        self._zapi.login(self._username, self._password)
        self._yaml_nodes: Dict[str, bool] = {}
        self._zabbix_nodes: Dict = {}
        self._zabbix_maint: Dict = {}

    @property
    def timeperiods(self) -> List[dict]:
        """Return the timeperiods in the format needed for zabbix api."""
        return [{'period': self._time_period}]

    def _get_config(self, name: str) -> Union[str, Path]:
        """Compares the two values and either returns to correct value or raise.

        This function either turn the value from args if set or the value from config.
        If both values are None the function raise an exception.

        Arguments:
            name: The name of the value to set

        Raise:
            ZabbixMaintError: If both values are None
        """
        args_value = vars(self._args).get(name)
        config_value = self._yaml_data.get(name)

        if args_value is None and config_value is None:
            raise ZabbixMaintError(
                f"{name}: must be set in either the config file passed as an argument",
            )
        return args_value if args_value else config_value

    @property
    def yaml_nodes(self) -> Dict[str, bool]:
        """Property to return the dict of yaml nodes."""
        if len(self._yaml_nodes) == 0:
            self.load_yaml_nodes()
        return self._yaml_nodes

    def load_yaml_nodes(self) -> None:
        """Load the yaml data calling this wil force a reload of yaml data from the repo."""
        for path in self._repo.glob('*.yaml'):
            fqdn = path.stem
            if self._filter is not None and not re.search(self._filter, fqdn):
                logger.info("%s: skipping, not matched by filter", fqdn)
                continue
            logger.debug("%s: loading yaml file form repo", fqdn)
            try:
                data = yaml.safe_load(path.read_text())
            except yaml.scanner.ScannerError as error:
                logger.error("%s: SKIPPING Unable to parse yaml - %s", path, error)
                continue

            try:
                self._yaml_nodes[fqdn] = data['status']['operational']
            except KeyError as error:
                logger.error(
                    "%s: SKIPPING unable to find operational value in yaml - %s",
                    path,
                    error,
                )
                continue

    @property
    def zabbix_maint(self) -> dict:
        """Property to access the zabbix maintenance object."""
        if len(self._zabbix_maint) == 0:
            self.load_zabbix_maint()
        return self._zabbix_maint

    def load_zabbix_maint(self) -> None:
        """Find or create the zabbix main object. Calling this will reload the data."""
        # TODO: ensure there is only one
        maint = self._zapi.maintenance.get(filter={'name': self.maintenance_name})
        logger.debug(maint)
        if len(maint) == 1:
            self._zabbix_maint = maint[0]
            return

        if len(maint) > 1:
            raise ZabbixMaintError(
                f"Found {len(maint)} matching: {self.maintenance_name}. expected 1"
            )

        active_since = int(time())
        active_till = active_since + self._time_period
        hostids = self.filter_hostids(False)
        if len(hostids) > 0:
            self._zabbix_maint = self._zapi.maintenance.create(
                name=self.maintenance_name,
                hostids=hostids,
                active_since=active_since,
                active_till=active_till,
                timeperiods=self.timeperiods,
            )

    @property
    def maintenanceid(self):
        """Return the maintenance id."""
        try:
            return self.zabbix_maint['maintenanceid']
        except KeyError:
            try:
                return self.zabbix_maint['maintenanceids'][0]
            except KeyError:
                return None

    def filter_nodes(self, search: bool = False) -> List[str]:
        """Filter the list of yaml hosts filtering on operational state.

        Arguments:
            search: return operational or none operational host

        Return:
            list: a list of hosts matching the filter
        """
        return [
            fqdn
            for fqdn, operational in self.yaml_nodes.items()
            if operational == search
        ]

    def filter_hostids(self, search: bool = False) -> List[str]:
        """Filter the list of yaml hosts filtering on operational state.

        Arguments:
            search: return operational or none operational host

        Return:
            list: a list of zabbix hostsids
        """
        return [
            node['hostid']
            for node in self.zabbix_nodes
            if node['host'] in self.filter_nodes(search)
        ]

    @property
    def zabbix_nodes(self) -> dict:
        """Propert to return list of zabbix nodes."""
        if len(self._zabbix_nodes) == 0:
            self.load_zabbix_nodes()
        return self._zabbix_nodes

    def load_zabbix_nodes(self) -> None:
        """Load the yaml data calling this will force a reload of zabbix data."""
        # This may not be needed
        output = ['hostid', 'status', 'host', 'maintenanceid', 'maintenance_status']
        self._zabbix_nodes = self._zapi.host.get(output=output)

    def update_maintenance(self) -> None:
        """Update the list of hosts for the maintenance."""
        active_till = int(time()) + self._time_period
        if self.maintenanceid is not None:
            self._zapi.maintenance.update(
                maintenanceid=self.maintenanceid,
                active_till=active_till,
                hostids=self.filter_hostids(False),
            )


def get_args(args: Optional[list] = None) -> Namespace:
    """Get and parse the arguments."""
    parser = ArgumentParser(description="add a host to zabbix")
    parser.add_argument(
        "-s",
        "--server",
        help="Zabbix API server to use",
    )
    parser.add_argument("-u", "--user", help="Zabbix API username")
    parser.add_argument("-p", "--password", help="Zabbix API password")
    parser.add_argument(
        "-c",
        "--config-file",
        type=Path,
        help="Path to the config file",
        default="/etc/zabbix/api.yaml",
    )
    parser.add_argument(
        "-r", "--repo", type=Path, help="Path to the repo containing your nodes"
    )
    parser.add_argument("-v", "--verbose", action="count", default=0)
    parser.add_argument("-q", "--quite", action="store_true")
    return parser.parse_args(args)


def get_log_level(args_level: int) -> int:
    """Convert an integer to a logging log level.

    Arguments:
        args_level (int): The log level as an integer

    Returns:
        int: the logging loglevel
    """
    return {
        0: logging.ERROR,
        1: logging.WARN,
        2: logging.INFO,
        3: logging.DEBUG,
    }.get(args_level, logging.DEBUG)


def main() -> int:
    """Main program Entry point.

    Returns:
        int: the status return code
    """
    args = get_args()
    logging.basicConfig(level=get_log_level(args.verbose))
    maintenances = {
        'IMRS operation: false': r'l\.dns\.icann\.org',
        'DNSeng operation: false': r'[^l]\.dns\.icann\.org',
    }

    try:
        for maintenance_name, fqdn_filter in maintenances.items():
            zabbix_maint = ZabbixMaint(
                args, maintenance_name=maintenance_name, fqdn_filter=fqdn_filter
            )
            zabbix_maint.update_maintenance()
            if not args.quite:
                not_operational_nodes = "\n".join(zabbix_maint.filter_nodes(False))
                print(
                    f"{maintenance_name}\n"
                    "The following nodes where added to the maintenance:\n",
                    not_operational_nodes
                )
    except ZabbixMaintError as error:
        logging.error(error)
        return 1

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
