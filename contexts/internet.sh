#!/usr/bin/env bash
# Context official repos (github, maven and node) on internet without proxy

GITHUB_URL="https://github.com"

context_metrics(){
    add_metric context internet
    add_metric repo officials
}