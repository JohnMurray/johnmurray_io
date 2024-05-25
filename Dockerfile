FROM ubuntu:22.04

RUN  apt-get update -y && apt-get install -y \
    git-core zlib1g-dev build-essential libssl-dev \
    libreadline-dev libyaml-dev libsqlite3-dev sqlite3 \
    libxml2-dev libxslt1-dev libcurl4-openssl-dev \
    software-properties-common libffi-dev wget

COPY .docker/ruby-install.sh /ruby-install.sh
RUN bash /ruby-install.sh && rm /ruby-install.sh

# Setup in previous ruby-install step
ENV PATH="/root/.asdf/shims:${PATH}"
ENV PATH="/root/.asdf/bin:${PATH}"

COPY .docker/gem-install.sh /gem-install.sh
RUN bash /gem-install.sh && rm /gem-install.sh

RUN mkdir /source
COPY Gemfile Gemfile.lock /source/
RUN cd /source && bundle install
RUN rm -rf /source
