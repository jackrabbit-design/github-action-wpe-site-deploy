FROM instrumentisto/rsync-ssh:alpine3.13-r4
RUN apk add git bash php
ADD entrypoint.sh /entrypoint.sh
ADD exclude.txt /exclude.txt
ENTRYPOINT ["/entrypoint.sh"]
