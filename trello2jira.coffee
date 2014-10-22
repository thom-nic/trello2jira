#!/usr/bin/env coffee

_ = require 'underscore'
async  = require 'async'
program = require 'commander'
Trello = require 'node-trello'
{JiraApi} = require 'jira'
usermap = require './users'

TRELLO_API_KEY = process.env.TRELLO_API_KEY
TRELLO_WRITE_ACCESS_TOKEN = process.env.TRELLO_WRITE_ACCESS_TOKEN
JIRA_USERNAME = process.env.JIRA_USERNAME
JIRA_PASSWORD = process.env.JIRA_PASSWORD
JIRA_HOST = process.env.JIRA_HOST

program
  .version '0.0.1'
  .description "Get the JSON object for a given issue"
  .option '-l, --trello_list <value>', 'Trello list id to pull from'
  .option '-s --status', 'Jira status to assign (which determines the destination column)'
  .option '-p --jira_project', 'Jira destination project key'
  .parse process.argv


TRELLO_LIST_ID = program.trello_list
PROJECT_KEY = program.jira_project
JIRA_STATUS = program.status

main = () ->
  trello = new Trello(TRELLO_API_KEY, TRELLO_WRITE_ACCESS_TOKEN)
  jira = new JiraApi('https', JIRA_HOST, 443, JIRA_USERNAME, JIRA_PASSWORD, '2')

  trello.get "/1/lists/#{TRELLO_LIST_ID}?cards=all", (err,list) ->

    console.log "#{list.name}:"
#    console.log list

    limit = 1
    count = 0
    for card in list.cards
      break if count++ > limit
      title = card.name
      description = card.desc
      type = if 'bug' in card.labels then "Bug" else "Task"
      status = if card.closed then "Rejected" else JIRA_STATUS
      console.log card.labels
      labels = (l.name for l in card.labels)

      console.log create_issue(PROJECT_KEY, title, description, type, JIRA_STATUS, labels)

      jira.addNewIssue create_issue(PROJECT_KEY, title, description, type, JIRA_STATUS, labels), 
        (err,resp) ->
          return console.error '\nError:', err if err

          process.stdout.write "  ", title
          create_link jira, resp.key, card.url, title
          create_comments jira, trello, resp.key, card.id
          process.stdout.write '\n'


create_issue = (project, title, description, type, status, labels, created, assigned) ->
  return fields:
    project:
      key: project
    summary: title
    description: description
    issuetype:
      name: type
    status:
      name: status
    labels: labels

create_comments = (jira, trello, issue, cardID) ->
  trello.get "/1/card/#{cardID}/actions?filter=commentCard", (err,resp) ->
    return console.error "Error getting comments", err if err
    console.log resp
    for comment in resp.actions
      create_comment jira, comment, issue

creat_comment = (jira, comment, issue) ->
  jira.addComment issue, comment, (err,resp) ->
    return console.error "Error adding comment to", issue, err if err

    process.stdout.write  ' ✉'

create_link = (jira, issue, trello_url, title) ->
  link = 
    globalId: trello_url
    object:
      url: trello_url
      title: title
    application:
      name: "Trello"
    relationship: "original"

  jira.createRemoteLink issue, link, (err,resp) ->
    return console.error "  Error creating link", err if err

    console.log " ✓"


main() if require.main == module
