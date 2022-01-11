FROM instrumentisto/rsync-ssh:alpine3.13-r4
RUN apk add git bash php openssh
RUN rc-update add sshd
RUN service sshd start
ADD entrypoint.sh /entrypoint.sh
ADD exclude.txt /exclude.txt
ENTRYPOINT ["/entrypoint.sh"]
