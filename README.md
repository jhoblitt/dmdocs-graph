Env variables for `docucrawl.rb`
---

    export DOCU_USER=$USER
    export DOCU_PASS=<password>

    # setup path for libreoffice4.4
    if [ -d /opt/libreoffice4.4/program/ ]; then
        PATH=/opt/libreoffice4.4/program/:$PATH
    fi

Setup git repo for images
---

    git config --local core.bigFileThreshold 100k
