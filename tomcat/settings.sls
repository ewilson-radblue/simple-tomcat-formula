{%- set p  = salt['pillar.get']('tomcat', {}) %}
{%- set g  = salt['grains.get']('tomcat', {}) %}

{%- set default_version       = '7.0.62' %}
{%- set default_archiveUrl    = 'http://archive.apache.org/dist/tomcat/tomcat-7/v7.0.62/bin/apache-tomcat-7.0.62.tar.gz' %}
{%- set default_archiveHash   = 'md5=656ed4914d68c8a048f29ebe76303796' %}
{%- set default_archiveFolder = 'apache-tomcat-7.0.62' %}
{%- set default_tomcatBase    = '/srv/tomcat' %}
{%- set default_tomcatUser    = 'tomcat' %}
{%- set default_tomcatGroup   = 'tomcat' %}

{%- set version       = p.get('version', g.get('version', default_version)) %}
{%- set archiveUrl    = p.get('archiveUrl', g.get('archiveUrl', default_archiveUrl)) %}
{%- set archiveHash   = p.get('archiveHash', g.get('archiveHash', default_archiveHash)) %}
{%- set archiveFolder = p.get('archiveFolder', g.get('archiveFolder', default_archiveFolder)) %}
{%- set tomcatBase    = p.get('tomcatBase', g.get('tomcatBase', default_tomcatBase)) %}
{%- set tomcatUser    = p.get('tomcatUser', g.get('tomcatUser', default_tomcatUser)) %}
{%- set tomcatGroup   = p.get('tomcatGroup', g.get('tomcatGroup', default_tomcatGroup)) %}

{%- set tomcat = {} %}
{%- do tomcat.update({ 
                        'version'       : version,
                        'archiveUrl'    : archiveUrl,
                        'archiveHash'   : archiveHash,
                        'archiveFolder' : archiveFolder,
                        'tomcatBase'    : tomcatBase,
                        'tomcatUser'    : tomcatUser,
                        'tomcatGroup'   : tomcatGroup
                      }) %}