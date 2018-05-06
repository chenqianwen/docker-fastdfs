FROM centos:7

LABEL maintainer "c-wms"

ENV FASTDFS_PATH=/opt/fdfs \
    FASTDFS_BASE_PATH=/var/fdfs \
    PORT= \
    GROUP_NAME= \
    TRACKER_SERVER=

#get all the dependences
RUN yum install -y git gcc make wget unzip vixie-cron \
    pcre pcre-devel openssl openssl-devel lua-devel \
    readline readline-devel perl-ExtUtils-Embed \
    libjpeg libjpeg-devel libpng libpng-devel giflib giflib-devel freetype freetype-devel  openjpeg openjpeg-devel \
    GraphicsMagick GraphicsMagick-devel  && \
    yum clean all

#create the dirs to store the files downloaded from internet
RUN mkdir -p ${FASTDFS_PATH}/libfastcommon \
 && mkdir -p ${FASTDFS_PATH}/fastdfs \
 && mkdir ${FASTDFS_BASE_PATH}

#compile the libfastcommon
WORKDIR ${FASTDFS_PATH}/libfastcommon

RUN git clone https://github.com/happyfish100/libfastcommon.git ${FASTDFS_PATH}/libfastcommon \
 && ./make.sh \
 && ./make.sh install \
 && rm -rf ${FASTDFS_PATH}/libfastcommon

#compile the fastdfs
WORKDIR ${FASTDFS_PATH}/fastdfs

RUN git clone https://github.com/happyfish100/fastdfs.git ${FASTDFS_PATH}/fastdfs \
 && ./make.sh \
 && ./make.sh install \
 && rm -rf ${FASTDFS_PATH}/fastdfs

COPY conf/*.* /etc/fdfs/


# Set timezone
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# Ready
RUN groupadd nginx && \
    useradd -g nginx nginx -s /bin/false

RUN wget http://rpmfind.net/linux/centos/7.4.1708/extras/x86_64/Packages/epel-release-7-9.noarch.rpm && \
    rpm -ivh epel-release-7-9.noarch.rpm && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

# Download and install package
RUN cd /tmp && \
    git clone https://github.com/LuaJIT/LuaJIT.git && \
    git clone https://github.com/simpl/ngx_devel_kit.git && \
    git clone https://github.com/openresty/lua-nginx-module.git && \
    git clone https://github.com/openresty/echo-nginx-module.git && \
    git clone https://github.com/FRiCKLE/ngx_cache_purge.git && \
    git clone https://github.com/happyfish100/fastdfs-nginx-module.git && \
    wget http://nginx.org/download/nginx-1.9.15.tar.gz

RUN cd /tmp && \
    tar zxvf nginx-1.9.15.tar.gz && \
    cd LuaJIT && \
    make && make install PREFIX=/usr/local/lj2 && \
    export LUAJIT_LIB=/usr/local/lj2/lib && \
    export LUAJIT_INC=/usr/local/lj2/include/luajit-2.0 && \
    cd ../nginx-1.9.15 && \
    ./configure --prefix=/usr/local/nginx --user=nginx --group=nginx --with-http_stub_status_module --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_gzip_static_module --add-module=/tmp/ngx_cache_purge --add-module=/tmp/fastdfs-nginx-module/src --add-module=/tmp/ngx_devel_kit --add-module=/tmp/echo-nginx-module/ --with-ld-opt=-Wl,-rpath,/usr/local/lj2/lib --add-module=/tmp/lua-nginx-module/ && \
    make && make install && \
    mv /usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf.bak && \
    mkdir /usr/local/nginx/conf/lua && \
    echo "0 2 * * * find /var/fdfs/data/ -name *.*_*x*.* -atime -7 | xargs rm -rf" >> /etc/crontab && \
    cp /tmp/fastdfs-nginx-module/src/mod_fastdfs.conf /etc/fdfs/ && \
    sed -i 's:base_path=.*:base_path=/var/fdfs:g' /etc/fdfs/mod_fastdfs.conf && \
    sed -i 's:store_path0=.*:store_path0=/var/fdfs:g' /etc/fdfs/mod_fastdfs.conf && \
    rm -rf /tmp/nginx-1.9.15 && \
    rm -rf /tmp/nginx-1.9.15.tar.gz


VOLUME ["$FASTDFS_BASE_PATH", "/etc/fdfs"]   

# Cpoy File
COPY file/nginx.conf /usr/local/nginx/conf/
COPY file/thumbnail.lua /usr/local/nginx/conf/lua/

COPY docker-entrypoint.sh /

#make the docker-entrypoint.sh executable 
RUN chmod 777 /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["tracker"]
