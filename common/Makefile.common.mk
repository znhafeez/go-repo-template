# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

############################################################
# install git hooks
############################################################
INSTALL_HOOKS := $(shell find .git/hooks -type l -exec rm {} \; && \
                         find common/scripts/.githooks -type f -exec ln -sf ../../{} .git/hooks/ \; )

############################################################
# lint section
############################################################

FINDFILES=find . \( -path ./.git -o -path ./.github \) -prune -o -type f
XARGS = xargs -0 ${XARGS_FLAGS}
CLEANXARGS = xargs ${XARGS_FLAGS}

lint-dockerfiles:
	@${FINDFILES} -name 'Dockerfile*' -print0 | ${XARGS} hadolint -c ./common/config/.hadolint.yml

lint-scripts:
	@${FINDFILES} -name '*.sh' -print0 | ${XARGS} shellcheck

lint-yaml:
	@${FINDFILES} \( -name '*.yml' -o -name '*.yaml' \) -print0 | ${XARGS} grep -L -e "{{" | ${CLEANXARGS} yamllint -c ./common/config/.yamllint.yml

lint-helm:
	@${FINDFILES} -name 'Chart.yaml' -print0 | ${XARGS} -L 1 dirname | ${CLEANXARGS} helm lint --strict

lint-copyright-banner:
	@${FINDFILES} \( -name '*.go' -o -name '*.cc' -o -name '*.h' -o -name '*.proto' -o -name '*.py' -o -name '*.sh' \) \( ! \( -name '*.gen.go' -o -name '*.pb.go' -o -name '*_pb2.py' \) \) -print0 |\
		${XARGS} common/scripts/lint_copyright_banner.sh

lint-go:
	@${FINDFILES} -name '*.go' \( ! \( -name '*.gen.go' -o -name '*.pb.go' \) \) -print0 | ${XARGS} common/scripts/lint_go.sh

lint-python:
	@${FINDFILES} -name '*.py' \( ! \( -name '*_pb2.py' \) \) -print0 | ${XARGS} autopep8 --max-line-length 160 --exit-code -d

lint-markdown:
	@${FINDFILES} -name '*.md' -print0 | ${XARGS} mdl --ignore-front-matter --style common/config/mdl.rb
ifdef MARKDOWN_LINT_WHITELIST
	@${FINDFILES} -name '*.md' -print0 | ${XARGS} awesome_bot --skip-save-results --allow_ssl --allow-timeout --allow-dupe --allow-redirect --white-list ${MARKDOWN_LINT_WHITELIST}
else
	@${FINDFILES} -name '*.md' -print0 | ${XARGS} awesome_bot --skip-save-results --allow_ssl --allow-timeout --allow-dupe --allow-redirect
endif

# lint-sass:
# 	@${FINDFILES} -name '*.scss' -print0 | ${XARGS} sass-lint -c common/config/sass-lint.yml --verbose

# lint-typescript:
# 	@${FINDFILES} -name '*.ts' -print0 | ${XARGS} tslint -c common/config/tslint.json

# lint-protos:
# 	@$(FINDFILES) -name '*.proto' -print0 | $(XARGS) -L 1 prototool lint --protoc-bin-path=/usr/bin/protoc

lint-all: lint-dockerfiles lint-scripts lint-yaml lint-helm lint-copyright-banner lint-go lint-python lint-markdown

# format-go:
# 	@${FINDFILES} -name '*.go' \( ! \( -name '*.gen.go' -o -name '*.pb.go' \) \) -print0 | ${XARGS} goimports -w -local "github.com/IBM"

# format-python:
# 	@${FINDFILES} -name '*.py' -print0 | ${XARGS} autopep8 --max-line-length 160 --aggressive --aggressive -i

# format-protos:
# 	@$(FINDFILES) -name '*.proto' -print0 | $(XARGS) -L 1 prototool format -w

.PHONY: lint-dockerfiles lint-scripts lint-yaml lint-helm lint-copyright-banner lint-go lint-python lint-markdown lint-all

############################################################
# multiarch image section
############################################################
ARCH := $(shell uname -m)

DEFAULT_S390X_IMAGE ?= ibmcom/pause-s390x:3.0
IMAGE_NAME_S390X ?= ${IMAGE_REPO}/${IMAGE_NAME}-s390x:${RELEASE_TAG}

.PHONY: s390x-fix
s390x-fix:
	manifest-tool inspect $(IMAGE_NAME_S390X) \
		|| (docker pull $(DEFAULT_S390X_IMAGE) \
		&& docker tag $(DEFAULT_S390X_IMAGE) $(IMAGE_NAME_S390X) \
		&& docker push $(IMAGE_NAME_S390X))

multi-arch: s390x-fix
	cp ./common/manifest.yaml /tmp/manifest.yaml
	sed -i -e "s|__RELEASE_TAG__|$(RELEASE_TAG)|g" -e "s|__IMAGE_NAME__|$(IMAGE_NAME)|g" -e "s|__IMAGE_REPO__|$(IMAGE_REPO)|g" /tmp/manifest.yaml
	manifest-tool push from-spec /tmp/manifest.yaml
