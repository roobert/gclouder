## GClouder

Google Cloud Resource Deployer

### Usage

#### Authentication

Authenticate against the GCP API:
```
gcloud auth login
gcloud auth application-default login
```

#### Examples

```
# only execute non-state-changing commands (i.e: API queries)
gclouder -c config.yaml --dry-run

# apply the config
gclouder -c config.yaml

# apply the config, also outputting the commands that are run and their output
gclouder -c config.yaml --debug

# apply the config and include stack trace on error
gclouder -c config.yaml --trace
```

### Install

#### Dependencies

##### Google Cloud SDK

Please see: https://cloud.google.com/sdk/downloads

##### Ruby

Requires a modern version of Ruby (>= 2.4), you can use rbenv or brew to install one, e.g:

```
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
. ~/.bashrc
rbenv install 2.4.0
rbenv global 2.4.0 # or `rbenv local 2.4.0` in gclouder dir
```

#### Gem Install

Pick one of the following two methods.

##### RubyGems

Normal installation:

```
gem install gclouder
```

##### Local Source

To install dependencies and run gclouder from source:

```
gem install bundler
bundle install
./bin/gclouder --help
```

### Testing


Test coverage is currently limited to libraries which are peripheral to the core functionality of this app, i.e: tests only exist for methods which can be independently tested of the GCP API.

There are plans to add integration tests at a later date.

To run the tests use one of the following:

Run once:
```
rake
```

To monitor changes to project files during development:
```
rake guard
```

### Notes

Each resource is designed to do the following:

* validation of local configuration by:
  * check parameters are valid arguments
  * check required parameters are set
  * check types are correct

* create remote instances which are defined locally

* check remote instance dont differs from local instance definitions

* remove instances which are no longer defined locally yet exist remotely

### Why?
* Google Deployment Manager is unable to manipulate resources not managed by itself
* It's not possible to resize things like clusters without using gcloud(1)
* Not all resources are supported by Google Deployment Manager
* Greater control over the magic that happens between our resource definitions and the remote resources
* Inter-project resources

### Gem

To build and install a gem run:

```
rake build
gem install pkg/gclouder-<version>.gem
```

To perform a release
```
# adjust version in lib/gclouder/version.rb then run:
rake release
```
