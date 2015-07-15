{%- from 'tomcat/settings.sls' import tomcat with context %}

tomcat_group:
  group.present:
    - name: tomcat
    - system: true

tomcat_user:
  user.present:
    - name: tomcat
    - home: /var/lib/tomcat
    - shell: /bin/false
    - system: true
    - empty_password: true
    - groups:
      - tomcat
    - require:
      - group: tomcat_group

tomcat_base_dir:
  file.directory:
    - name: {{ tomcat.tomcatBase }}
    - user: tomcat
    - group: tomcat

### Loop over the instances ###
{% for instance, instance_dict in salt['pillar.get']('tomcat:instances').items() %}

tomcat_{{ instance }}_archive:
  archive.extracted:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}
    - source: {{ tomcat.archiveUrl }}
    - source_hash: {{ tomcat.archiveHash }}
    - archive_format: tar
    - archive_user: tomcat
    - tar_options: v
    - if_missing: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.archiveFolder }}

tomcat_{{ instance }}_archive_link_{{ tomcat.version }}:
  file.symlink:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}
    - target: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.archiveFolder }}
    - user: tomcat
    - group: tomcat

tomcat_{{ instance }}_archive_link_current:
  file.symlink:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/current
    - target: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}
    - user: tomcat
    - group: tomcat

tomcat_{{ instance }}_files_setenv:
  file.managed:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}/bin/setenv.sh
    - user: tomcat
    - group: tomcat
    - mode: 750
    - template: jinja
    - contents_pillar: tomcat:instances:{{ instance }}:files:setenv:contents
    - require:
      - file: tomcat_{{ instance }}_archive_link_{{ tomcat.version }}
    - require_in:
      - file: tomcat_{{ instance }}_dirperms
    - watch_in:
      - service: tomcat_{{ instance }}_service

tomcat_{{ instance }}_files_init:
  file.managed:
    - name: /etc/init.d/tomcat-{{ instance }}
    - source: salt://tomcat/files/init
    - user: tomcat
    - group: tomcat
    - mode: 755
    - context:
      i_name: {{ instance }}
    - template: jinja
    - require:
      - file: tomcat_{{ instance }}_archive_link_{{ tomcat.version }}
    - require_in:
      - file: tomcat_{{ instance }}_dirperms
    - watch_in:
      - service: tomcat_{{ instance }}_service

tomcat_{{ instance }}_files_tomcat_users:
  file.managed:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}/conf/tomcat-users.xml
    - source: salt://tomcat/files/tomcat_users
    - user: tomcat
    - group: tomcat
    - mode: 640
    - context: 
      users: |
        {{ instance_dict['settings']['users'] | indent(8) }}
    - template: jinja
    - require:
      - file: tomcat_{{ instance }}_archive_link_{{ tomcat.version }}
    - require_in:
      - file: tomcat_{{ instance }}_dirperms
    - watch_in:
      - service: tomcat_{{ instance }}_service

tomcat_{{ instance }}_files_server:
  file.managed:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}/conf/server.xml
    - source: salt://tomcat/files/server
    - user: tomcat
    - group: tomcat
    - mode: 640
    - context: 
      shutdown_port: {{ instance_dict['settings']['ports'].get('shutdown_port', 8005) }}
      http_port: {{ instance_dict['settings']['ports'].get('http_port', 8080) }}
      https_port: {{ instance_dict['settings']['ports'].get('https_port', 8443) }}
      ajp_port: {{ instance_dict['settings']['ports'].get('ajp_port', 8009) }}
    - template: jinja
    - require:
      - file: tomcat_{{ instance }}_archive_link_{{ tomcat.version }}
    - require_in:
      - file: tomcat_{{ instance }}_dirperms
    - watch_in:
      - service: tomcat_{{ instance }}_service

tomcat_{{ instance }}_dirperms:
  file.directory:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}
    - user: tomcat
    - group: tomcat
    - mode: 755
    - recurse:
      - user
      - group

### Loop over Webapps for this instance ###
{% for webapp, webapp_dict in instance_dict.get('webapps').items() %}
{% set app_dir = webapp_dict.get('alias', webapp) %}

# "ensure: absent" indicates that a pre-existing webapp should be removed
{% if webapp_dict.get('ensure') == 'absent' %}
tomcat_{{ instance }}_webapp_{{ webapp }}_dir:
  file.absent:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}/webapps/{{ app_dir }}
    - require_in:
      - tomcat_{{ instance }}_dirperms

# "ensure: exists" will perform a check that the webapp directory exists
{% elif webapp_dict.get('ensure') == 'exists' %}
tomcat_{{ instance }}_webapp_{{ webapp }}_dir:
  file.exists:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}/webapps/{{ app_dir }}
    - require_in:
      - tomcat_{{ instance }}_service

# "deployment: simple-war" will simply copy the war file to the given directory
{% elif webapp_dict.get('deployment') == 'simple-war' %}
tomcat_{{ instance }}_webapp_{{ webapp }}_dir:
  file.managed:
    - name: {{ tomcat.tomcatBase }}/{{ instance }}/{{ tomcat.version }}/webapps/{{ app_dir }}
    - source: {{ webapp_dict.get('source') }}
{% if webapp_dict.get('source_hash') %}
    - source_hash: {{ webapp_dict.get('source_hash') }}
{% endif %}
    - user: tomcat
    - group: tomcat
    - mode: 644
    - require_in:
      - tomcat_{{ instance }}_dirperms

# "deployment: manager-war" will deploy the war through the Tomcat Manager webapp
{% elif webapp_dict.get('deployment') == 'manager-war' %}
tomcat_{{ instance }}_webapp_{{ webapp }}_deploy:
  tomcat.war_deployed:
    - name: /{{ app_dir }}
    - war: {{ webapp_dict.get('source') }}
    - url: {{ webapp_dict.get('manager_url') }}
    - timeout: {{ webapp_dict.get('timeout', 180) }}
    - require:
      - service: tomcat_{{ instance }}_service
{% endif %}

{% endfor %}
### End loop over webapps for this instance ###

tomcat_{{ instance }}_service:
  service.running:
    - name: tomcat-{{ instance }}
    - enable: true
    - require:
      - file: tomcat_{{ instance }}_dirperms

{% endfor %}
### End loop over instances ###