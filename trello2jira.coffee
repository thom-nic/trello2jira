#!/usr/bin/env coffee

_ = require 'lodash'
async  = require 'async'
program = require 'commander'
Trello = require 'node-trello'
{JiraApi} = require 'jira'

TRELLO_API_KEY = process.env.TRELLO_API_KEY
TRELLO_ACCESS_TOKEN = process.env.TRELLO_ACCESS_TOKEN
JIRA_USERNAME = process.env.JIRA_USERNAME
JIRA_PASSWORD = process.env.JIRA_PASSWORD
JIRA_HOST = process.env.JIRA_HOST

program
  .version '0.0.1'
  .description "Get the JSON object for a given issue"
  .option '-l, --trello_list <value>', 'Trello list id to pull from'
  .option '-s --status <status>', 'Jira status to assign (which determines the destination column)'
  .option '-p --jira_project <jira_project>', 'Jira destination project key'
  .parse process.argv

TRELLO_LIST_ID = program.trello_list
PROJECT_KEY = program.jira_project
JIRA_STATUS = program.status

main = () ->
  trello = new Trello(TRELLO_API_KEY, TRELLO_ACCESS_TOKEN)
  jira = new JiraApi('https', JIRA_HOST, 443, JIRA_USERNAME, JIRA_PASSWORD, '2')

  trello.get "/1/lists/#{TRELLO_LIST_ID}?cards=all", (err,list) ->

    console.log "#{list.name}:"
#    console.log list

    limit = 1
    count = 0
    async.eachSeries list.cards, (card, next) ->
      title = card.name
      description = card.desc
      type = if 'bug' in card.labels then "Bug" else "Task"
      status = if card.closed then "Rejected" else JIRA_STATUS
#        console.log "Labels", card.labels
      labels = (l.name for l in card.labels)

#        console.log create_issue(PROJECT_KEY, title, description, type, JIRA_STATUS, labels)

      async.waterfall [
        _.partial( create_issue, jira, PROJECT_KEY, title, description, type, labels )
#        , _.partial set_status jira, status
        , _.partial( create_link, jira, card.url, title )
        , _.partial( create_comments, jira, trello, card.id ) 
      ]
      , (err, results) ->
        console.error err if err
        next err



create_issue = (jira, project, title, description, type, labels, next) ->
  issue =
    fields:
      project:
        key: project
      summary: title
      description: description
      issuetype:
        name: type
      labels: labels

  jira.addNewIssue issue,  (err,resp) ->
    return next "Error creating issue #{err}" if err

    issue = resp.key

    process.stdout.write "\n ➤  #{title}"
    process.stdout.write ' ✘' if type == 'Bug'
    next null, issue


set_status = (jira, status, issue, next) ->
  transition = 
    transition:
      name: status

  jira.transitionIssue issue, transition, (err,resp) ->
    return "Error setting status #{err}" if err

    process.stdout.write " ✓"
    next null, issue

    
create_comments = (jira, trello, card_id, issue, next) ->
  trello.get "/1/card/#{card_id}/actions?filter=commentCard", (err,comments) ->
    return next "Error getting comments: #{err}" if err
#    console.log "Comments", comments
    
    return next() unless comments.length
    async.eachSeries comments, _.partial(create_comment, jira, issue), (err) ->
      next err, issue

create_comment = (jira, issue, comment, next) ->
  jira.addComment issue, comment.data.text, (err,resp) ->
    return next "Error adding comment to #{issue}: #{err}" if err

    process.stdout.write  ' ✎'
    next()


create_link = (jira, trello_url, title, issue, next) ->
  link = 
    globalId: trello_url
    object:
      url: trello_url
      title: title
    application:
      name: "Trello"
    relationship: "Trello"

  jira.createRemoteLink issue, link, (err,resp) ->
    if err && ! err.toString().match /^201/
      return next "Error creating link: #{err}"

    process.stdout.write " ✪"
    next null, issue


main() if require.main == module
