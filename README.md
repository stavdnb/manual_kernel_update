## Homework-01

Для выполнения данного ДЗ в файле centos.json была добавлена строка 
``` "headless": "true"   ``` - которая позволяет запускать машину в Virtualbox без использования GUI

С помощью строки ```. config.vm.synced_folder "~/shared_os" , "/vagrant" ``` в файле Vagrantfile мы пробрасываем локальную папку ~/shared_os внутрь ВМ

При публикации собранного образа в Vagrant Cloud столкнулся с ошибкой SSL , решается следующим образом : 

В файле ``` /opt/vagrant/embedded/lib/ruby/2.6.0/openssl/ssl.rb ``` необходимо привести строку к следующему виду ``` TLSv1: OpenSSL::SSL::TLS1_2_VERSION ```

Таким образом мы включаем поддержку TLS 1.2 во встроенном окружении Ruby
