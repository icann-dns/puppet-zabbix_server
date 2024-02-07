# pylint: disable=protected-access, too-many-arguments
"""Tester for the ZabbixMaint class"""
import logging

from pathlib import Path

import mock
import pytest

from zabbix_maintenance import (
    get_args,
    get_log_level,
    main,
    ZabbixMaint,
    ZabbixMaintError,
)


API_YAML = """---
server: http://zabbix.example.org
username: zabbix
password: zabbix_password
repo: /etc/hieradata
"""
BAD_YAML = 'a: -'
NODE_YAML = """---
status:
    operational: False
"""


class TestZabbixMaint:
    """Class for testing the ZabbixMaint class."""

    @pytest.fixture(autouse=True)
    def setup_method(self, requests_mock):
        """Initialize the test instance."""
        # pylint: disable=attribute-defined-outside-init
        self.args = get_args([])
        self.requests_mock = requests_mock

        # with mock.patch('zabbix_maintenance.Path.is_file', return_value=True):
        #    with mock.patch('zabbix_maintenance.Path.read_text', return_value=API_YAML):
        @mock.patch('zabbix_maintenance.Path.is_file', return_value=True)
        @mock.patch('zabbix_maintenance.Path.read_text', return_value=API_YAML)
        @mock.patch('zabbix_maintenance.Path.is_dir', return_value=True)
        @mock.patch('zabbix_maintenance.ZabbixAPI.login', return_value=True)
        def create_instance(_mock_login, _mock_is_dir, _mock_read_text, _mock_is_file):
            self.zabbix_maintenance = ZabbixMaint(
                self.args, maintenance_name="test", fqdn_filter="include"
            )

        create_instance()  # pylint: disable=no-value-for-parameter
        assert isinstance(self.zabbix_maintenance, ZabbixMaint)

    @pytest.mark.parametrize(
        'is_file_return, read_text_return, is_dir_return, match',
        (
            (False, None, None, '/etc/zabbix/api.yaml'),
            (True, BAD_YAML, None, 'Unable to parse yaml: /etc/zabbix/api.yaml'),
            (True, API_YAML, False, '/etc/hieradata: dose not exist'),
            (
                True,
                '{}',
                True,
                'server: must be set in either the config file passed as an argument',
            ),
        ),
    )
    @mock.patch('zabbix_maintenance.ZabbixAPI.login', return_value=True)
    @mock.patch('zabbix_maintenance.Path.is_dir')
    @mock.patch('zabbix_maintenance.Path.read_text')
    @mock.patch('zabbix_maintenance.Path.is_file')
    def test_raise_missing_data(
        self,
        mock_is_file,
        mock_read_text,
        mock_is_dir,
        _mock_login,
        is_file_return,
        read_text_return,
        is_dir_return,
        match,
    ):
        """Test that the _get_config object throws an error"""
        mock_is_file.return_value = is_file_return
        mock_read_text.return_value = read_text_return
        mock_is_dir.return_value = is_dir_return
        mock_is_file.return_value = is_file_return
        with pytest.raises(ZabbixMaintError, match=match):
            ZabbixMaint(self.args, maintenance_name="test")

    def test_timeperiods(self):
        """Test the time periods property."""
        assert self.zabbix_maintenance.timeperiods == [
            {'period': self.zabbix_maintenance._time_period}
        ]

    @pytest.mark.parametrize(
        'data, len_return',
        (
            ({}, 0),
            ({}, 1),
        ),
    )
    @mock.patch('zabbix_maintenance.len')
    @mock.patch('zabbix_maintenance.ZabbixMaint.load_yaml_nodes')
    def test_yaml_nodes_property(
        self, mock_load_yaml_nodes, mock_len, data, len_return
    ):
        """Test the yaml_nodes property."""
        mock_len.return_value = len_return
        self.zabbix_maintenance._yaml_nodes = data
        assert self.zabbix_maintenance.yaml_nodes == data
        if len_return == 0:
            mock_load_yaml_nodes.assert_called_once()

    @pytest.mark.parametrize(
        'safe_load_return, num_nodes',
        (
            ({}, 0),
            ({'status': {'operational': True}}, 1),
            ({'status': {'operational': False}}, 1),
        ),
    )
    @mock.patch('zabbix_maintenance.yaml.safe_load')
    @mock.patch(
        'zabbix_maintenance.Path.glob', return_value=[Path('include'), Path('exclude')]
    )
    def test_load_yaml_nodes(
        self, mock_glob, mock_safe_load, safe_load_return, num_nodes
    ):
        """Test loading yaml"""
        mock_safe_load.return_value = safe_load_return
        with mock.patch.object(Path, 'read_text'):
            self.zabbix_maintenance.load_yaml_nodes()
        mock_glob.assert_called_once()
        assert len(self.zabbix_maintenance._yaml_nodes) == num_nodes

    @mock.patch('zabbix_maintenance.Path.glob')
    def test_load_bad_node_yaml(self, mock_glob):
        """Test reading bad yaml for nodes."""
        mock_glob.return_value = [Path('include')]
        with mock.patch.object(Path, 'read_text', return_value=BAD_YAML):
            self.zabbix_maintenance.load_yaml_nodes()
            assert len(self.zabbix_maintenance._yaml_nodes) == 0

    @pytest.mark.parametrize(
        'data, len_result',
        (
            ({}, 0),
            ({}, 1),
        ),
    )
    @mock.patch('zabbix_maintenance.len')
    @mock.patch('zabbix_maintenance.ZabbixMaint.load_zabbix_maint')
    def test_zabbix_maint(self, mock_load_zabbix_maint, mock_len, data, len_result):
        """Test the zabbix maint property."""
        mock_len.return_value = len_result
        self.zabbix_maintenance._zabbix_maint = data
        assert self.zabbix_maintenance.zabbix_maint == data
        if len_result == 0:
            mock_load_zabbix_maint.assert_called_once()

    @pytest.mark.parametrize(
        'zabbix_maint_return, return_value',
        (
            ({'maintenanceid': 42}, 42),
            ({'maintenanceids': [42]}, 42),
        ),
    )
    def test_maintenanceid(self, zabbix_maint_return, return_value):
        """Test maintenance id"""
        self.zabbix_maintenance._zabbix_maint = zabbix_maint_return
        assert self.zabbix_maintenance.maintenanceid == return_value

    @pytest.mark.parametrize(
        'orig_nodes, filter_true, filter_false',
        (
            (
                {'none_operational1': False, 'operational1': True},
                ['operational1'],
                ['none_operational1'],
            ),
            (
                {'none_operational1': False, 'none_operational2': False},
                [],
                ['none_operational1', 'none_operational2'],
            ),
            (
                {'operational1': True, 'operational2': True},
                ['operational1', 'operational2'],
                [],
            ),
        ),
    )
    def test_filter_nodes(self, orig_nodes, filter_true, filter_false):
        """Test the filter nodes."""
        self.zabbix_maintenance._yaml_nodes = orig_nodes
        assert self.zabbix_maintenance.filter_nodes(True) == filter_true
        assert self.zabbix_maintenance.filter_nodes(False) == filter_false

    @pytest.mark.parametrize(
        'orig_nodes, filter_true, filter_false',
        (
            (
                {'none_operational1': False, 'operational1': True, 'missing': False},
                ['1'],
                ['3'],
            ),
            (
                {
                    'none_operational1': False,
                    'none_operational2': False,
                    'missing': False,
                },
                [],
                ['3', '4'],
            ),
            (
                {'operational1': True, 'operational2': True, 'missing': True},
                ['1', '2'],
                [],
            ),
        ),
    )
    def test_filter_hostids(self, orig_nodes, filter_true, filter_false):
        """Test the filter nodes."""
        self.zabbix_maintenance._zabbix_nodes = [
            {'host': 'operational1', 'hostid': '1'},
            {'host': 'operational2', 'hostid': '2'},
            {'host': 'none_operational1', 'hostid': '3'},
            {'host': 'none_operational2', 'hostid': '4'},
        ]
        self.zabbix_maintenance._yaml_nodes = orig_nodes
        assert self.zabbix_maintenance.filter_hostids(True) == filter_true
        assert self.zabbix_maintenance.filter_hostids(False) == filter_false

    def test_load_zabbix_maint_found(self):
        """Test the load_zabbix_maint method."""
        json_response = {'result': [{'maintenanceid': '1'}]}
        self.requests_mock.post('/api_jsonrpc.php', json=json_response)
        self.zabbix_maintenance.load_zabbix_maint()
        assert self.zabbix_maintenance.zabbix_maint == json_response['result'][0]
        assert self.zabbix_maintenance.maintenanceid == '1'

    def test_load_zabbix_maint_multi_found(self):
        """Test the load_zabbix_maint method."""
        json_response = {'result': [{'maintenanceid': '1'}, {'maintenanceid': '2'}]}
        self.requests_mock.post('/api_jsonrpc.php', json=json_response)
        with pytest.raises(
            ZabbixMaintError,
            match="Found 2 matching: test. expected 1",
        ):
            self.zabbix_maintenance.load_zabbix_maint()

    @pytest.mark.parametrize(
        'hostids, maintenanceid',
        (
            (["1"], "1"),
            ([], None),
        )
    )
    @mock.patch('zabbix_maintenance.ZabbixMaint.filter_hostids')
    def test_load_zabbix_maint_create_new(self, mock_filter_hostids, hostids, maintenanceid):
        """Test the load_zabbix_maint method."""
        mock_filter_hostids.return_value = hostids

        def response_callback(request, _context):
            if 'maintenance.create' in request.text:
                return {"result": {"maintenanceids": ["1"]}}
            return {'result': []}

        self.requests_mock.post('/api_jsonrpc.php', json=response_callback)
        self.zabbix_maintenance.load_zabbix_maint()
        assert self.zabbix_maintenance.maintenanceid == maintenanceid

    @mock.patch('zabbix_maintenance.ZabbixMaint.filter_hostids', return_value=['1'])
    def test_update_maintenance(self, mock_filter_hostids):
        """Test the update maint."""
        self.zabbix_maintenance._zabbix_maint = {'maintenanceids': ['1']}
        self.requests_mock.post(
            '/api_jsonrpc.php', json={'result': {'maintenanceids': ['1']}}
        )
        self.zabbix_maintenance.update_maintenance()
        mock_filter_hostids.assert_called_once()


def test_get_log_level():
    """Test get_log_level function."""
    assert get_log_level(0) == logging.ERROR
    assert get_log_level(1) == logging.WARN
    assert get_log_level(2) == logging.INFO
    assert get_log_level(3) == logging.DEBUG
    assert get_log_level(4) == logging.DEBUG
    assert get_log_level(255) == logging.DEBUG


@mock.patch('zabbix_maintenance.ZabbixMaint')
@mock.patch('zabbix_maintenance.get_args', return_value=get_args([]))
def test_main(mock_get_args, _mock_zabbix_maint):
    """Test the main function."""
    assert main() == 0
    mock_get_args.assert_called_once()


@mock.patch('zabbix_maintenance.ZabbixMaint')
@mock.patch('zabbix_maintenance.get_args', return_value=get_args(['-q']))
def test_main_quite(mock_get_args, _mock_zabbix_maint):
    """Test the main function."""
    assert main() == 0
    mock_get_args.assert_called_once()


@mock.patch('zabbix_maintenance.get_args', return_value=get_args([]))
def test_main_exception(mock_get_args):
    """Test the main function."""
    assert main() == 1
    mock_get_args.assert_called_once()
