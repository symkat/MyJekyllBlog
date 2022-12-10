# MyJekyllBlog Ansible Tools

MyJekyllBlog uses [Ansible]() for system configuration, installation, and maintenance.

You can find an example [inventory file](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html) in `env/example/inventory.yml`.  Secrets are kept secure by using [ansible vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) on the `env/example/vault.yml` file.

There are [ansible roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html) in the `roles/` directory.  Roles named with `-profile-` are specific to a given machine type. Roles named with `-role-` are intended to be included from other roles. Roles named with `-overlay-` or `-task-` are intended to be run against an already-configured instance in a stand-alone playbook to accomplish a specific configuration or task.

## Cheat Sheet

If your environment is named `stage`:

```bash
# Initial encryption of the vault file with our secrets.
ansible-vault encrypt --vault-password-file .vault_password env/stage/vault.yml

# Editing it once it has been encrypted.
ansible-vault edit --vault-password-file .vault_password env/stage/vault.yml

# Running the playbook to ensure everything is setup:
ansible-playbook -i env/stage/inventory.yml --vault-password-file .vault_password -e @env/stage/vault.yml site.yml

# Updateing MJB Software & Restarting mjb.panel, mjb.worker, and mjb.certbot
ansible-playbook -i env/stage/inventory.yml --vault-password-file .vault_password -e @env/stage/vault.yml update-software.yml
```


