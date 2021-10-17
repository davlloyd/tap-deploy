kubectl create secret docker-registry tap-registry \
-n tap-install \
--docker-server='registry.pivotal.io' \
--docker-username=<PIVNET_USER> \
--docker-password=<PIVNET_PASSWORD>