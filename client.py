from keystoneauth1.identity import v3
from keystoneauth1 import session as k_session
from novaclient import client
from neutronclient.v2_0 import client as neutron_client
import flask


class OpenStackClient(object):
    def __init__(self):
        try:
            auth = v3.Password(auth_url='http://192.168.0.179:5000/v3',
                               username='admin',
                               password='secret',
                               project_name='admin',
                               user_domain_id='default',
                               project_domain_id='default')
            self.sess = k_session.Session(auth=auth)
        except:
            return str("User not logged in")


class NovaClient(OpenStackClient):
    def __init__(self):
        super(NovaClient, self).__init__()
        self.nova = client.Client("2.1", session=self.sess)

    def check_keystone(self):
            if (self.nova.flavors.list()):
                return True

    def novaflavorlist(self):
            return self.nova.flavors.list()

    def novaimagelist(self):
            return self.nova.images.list()

    def avail_zone_session(self):
           return self.nova.availability_zones.list()

    def novaboot(self):
            image = self.nova.images.find(name=flask.session['image'])#name="cirros-0.3.4-x86_64-uec")
            fl = self.nova.flavors.find(name=flask.session['flavor'])#name="m1.tiny")
            self.nova.servers.create(flask.session['name'], flavor=fl, image=image)

    def nova_vm_list(self):
            return self.nova.servers.list()

    def nova_vm_delete(self):
        instance_list = self.nova.servers.list()
        for ins in instance_list:
                if ins.name == flask.session['vm_delete']:
                    self.nova.servers.delete(ins.id)


class NeutronClient(OpenStackClient):
    def __init__(self):
        super(NeutronClient, self).__init__()
        self.neutron = neutron_client.Client(session=self.sess)

    def networkcreate(self):
        network1 = {'name': flask.session['network_name']}
        self.neutron.create_network({'network': network1})

    def netlist(self):
        network_list = self.neutron.list_networks()
        netlist = []
        temp_list = network_list['networks']
        for i in temp_list:
            for k, v in i.iteritems():
                k1 = '<'+k+'>'
                v1= '<'+v+'>'
                w = 'k1:v1'
                netlist.append(w)
        return str(netlist)

    def netdelete(self):
        net_list = self.netlist()
        for network in net_list:
            if network.name == flask.session['network_name'] :
                net_id = network.id
                self.neutron.delete_network(net_id)




