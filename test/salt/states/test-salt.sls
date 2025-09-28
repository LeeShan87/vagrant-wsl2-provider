# Test Salt state for WSL2 provider

salt_test_message:
  cmd.run:
    - name: echo "Hello from SaltStack on WSL2!" > /home/vagrant/salt-test.txt
    - user: vagrant
    - cwd: /home/vagrant
    - creates: /home/vagrant/salt-test.txt

install_curl:
  pkg.installed:
    - name: curl

create_salt_test_directory:
  file.directory:
    - name: /home/vagrant/salt-test
    - user: vagrant
    - group: vagrant
    - mode: 755

salt_test_completion:
  cmd.run:
    - name: echo "SaltStack provisioner completed successfully on $(hostname)" >> /home/vagrant/salt-test.txt
    - user: vagrant
    - require:
      - cmd: salt_test_message