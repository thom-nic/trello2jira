#!/usr/bin/env coffee

_ = require 'underscore'
async  = require 'async'
program = require 'commander'
Trello = require 'node-trello'
{JiraApi} = require 'jira'

JIRA_USERNAME = process.env.JIRA_USERNAME
JIRA_PASSWORD = process.env.JIRA_PASSWORD
JIRA_HOST = process.env.JIRA_HOST

program
  .version '0.0.1'
  .description "Get the JSON object for a given issue"
  .usage '<id>'
  .option '<id>', 'issue ID'
  .parse process.argv

main = ->
  unless JIRA_USERNAME and JIRA_PASSWORD
    console.err "Missing username"
    process.exit 1
    
  jira = new JiraApi('https', JIRA_HOST, 443, JIRA_USERNAME, JIRA_PASSWORD, '2', true)

  [id] =  program.args

  jira.findIssue id, (err,issue) ->
    return console.error "Error", err if err
    
    console.log issue
  
  
main() if require.main == module
