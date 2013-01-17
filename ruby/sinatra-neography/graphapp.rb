require 'rubygems'
require 'sinatra'
require 'neography'
require 'net/http'
require 'uri'
require 'json'

neo4j_uri = URI(ENV['NEO4J_URL'] || 'http://localhost:7474')
neo = Neography::Rest.new(neo4j_uri.to_s) # Neography expects a string

def check_for_neo4j(neo4j_uri)
  begin
    http = Net::HTTP.new(neo4j_uri.host, neo4j_uri.port)
    request = Net::HTTP::Get.new(neo4j_uri.request_uri)
    request.basic_auth(neo4j_uri.user, neo4j_uri.password) if (neo4j_uri.user)
    response = http.request(request)

    if response.code != '200'
      abort "Sad face. Neo4j does not appear to be running. #{neo4j_uri} responded with code: #{response.code}"
    end
  rescue
    abort "Sad face. Neo4j does not appear to be running at #{neo4j_uri} (" + $!.to_s + ')'
  end
  puts "Awesome! Neo4j is available at #{neo4j_uri}"
end

def create_graph(neo)
  # use the imperative API to create a simple graph: (Neo4j)-[:loves]->(you)
  # Graphs store data in nodes and relationships, with properties on both. 
  # By convention, text representations of a graph use parenthesis to indicate 
  # a node and square brackets to indicate a relationship.

  # 1. get the 'from' node, which we expect to be named "Neo4j"
  from = neo.get_root # we'll use the root node as the 'from'
  puts from.inspect

  # 2. get the properties of the 'from' node
  properties = neo.get_node_properties(from)

  # 3. if a 'name' property exists, assume we've already created the graph
  return if properties && properties['name']

  # 4. otherwise, set the 'name' property
  neo.set_node_properties(from, {:name => 'Neo4j'})

  # 5. create the 'to' node
  to = neo.create_node(:name => 'you')

  # 6. create a 'loves' relationship from the 'from' node to the 'to' node
  neo.create_relationship('loves', from, to)

  # To learn more, read the excellent Neo4j Manual at http://docs.neo4j.org
end

check_for_neo4j(neo4j_uri)

create_graph(neo)

def lovers_find(neo)
  cypher_query = 'START n=node(*) ' + # start by considering all nodes in the graph
      'MATCH (n)-[r:loves]->(m) ' + # pattern match any node 'n' with an outgoing 'loves' relationship 'r' to some other node 'm'
      'return n, r, m' # return both nodes, and the relationship between them

  results = neo.execute_query(cypher_query) # execute the query, capture results

  row = results['data'].first
  return cypher_query, row
end

get '/' do
  # Cypher is a graph query language that uses pattern matching.
  @cypher_query, @row = lovers_find(neo) # we just want the first row of the result data

  # Output the name property of the 'm' node, the relationship type of 'r' and the name property of the 'm' node.
  erb :index

end
