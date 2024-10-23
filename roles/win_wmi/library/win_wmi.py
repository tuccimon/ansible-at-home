#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2019, tuccimon
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# this is a windows documentation stub. actual code lives in the .ps1
# file of the same name

ANSIBLE_METADATA = {'metadata_version': '1.0',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = r'''
---
module: win_wmi
version_added: '1.0'
short_description: Add, change, or remove WMI Namespaces, Classes, Properties and values
description:
- Add, change, or remove WMI Namespaces, Classes, Properties and values
- More information about the windows management instrumentation from Wikipedia
  U(https://en.wikipedia.org/wiki/Windows_Management_Instrumentation).
options:
  namespace:
    description: 
    - Name of the namespace.
    - 'Module will always assume starting at root\ even if not specified'
    type: str
    required: yes
  class: 
    description: 
    - Name of the class entry in the above C(namespace) parameter.
    type: str
    required: only if property specified
  property:
    description: 
    - Name of the property which is or to be contained in the C(class) parameter.
    type: str
    required: only if value is specified
  data:
    description: 
    - Value of the C(property) entry in the C(class) and C(namespace).
    type: str
  type:
    description: 
    - The data type of the C(data) parameter.
    type: str
  state:
    description: 
    - The state of the value, property, class or namespace.
    type: str
    choices: [ absent, present ]
    default: present
  recursive:
    description: 
    - Whether to act in recursive fashion from the lowest parameter specified.
    type: bool
    default: yes
notes:
- There are quite a few different data types. It will take any string value and try to use them in the script, but will return an error if it fails.
author:
- Carlo Clementucci (@tuccimon)
'''

EXAMPLES = r'''
- name: create your own namespace under root
  win_wmi:
    namespace: MyNamespace

- name: create your own class under your new namespace
  win_wmi:
    namespace: MyNamespace
    class: MyClass

- name: create your own property and assign it a value of 0 (this will do all of the above if they are not present)
  win_wmi:
    namespace: MyNamespace
    class: MyClass
    property: MyProperty
    value: 0

- name: only delete property item
  win_wmi:
    namespace: MyNamespace
    class: MyClass
    property: MyProperty
    state: absent

- name: delete entire namespace (use with caution)
  win_wmi:
    namespace: MyNamespace
    state: absent
'''

RETURN = r'''
#
'''