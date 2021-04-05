#!/usr/bin/env bash

set -e

# Title: Build your first (something) by using Azure Cache for Redis
# (What's the "something" here?)

# Here's the pattern I'm proposing:
# Unit 1 - Introduction
# Unit 2 - (Talk about provisioning options)
# Unit 3 - Exercise - Create an instance of (Azure service)
# Unit 4 - (Talk about working with the service)
# Unit 5 - Exercise - Build a (noun) that (accoplishes task) 
# Unit 6 - (Talk about managing the service)
# Unit 7 - Exercise - Update the (some aspect of the service)
# Unit 8 - Knowledge check
# Unit 9 - Summary

# Said another way:
# * We have 3 knowledge / exercise unit pairs.
# * The first pair is about bringing up the service - discuss options but thing the thing up through the Azure portal.
# * The second pair is about working with the service - try demonsrate what the service can do.
# * The third pair is about managing the service - tweaking options, making it secure, and so on.

# By now, folks should have gone through the "Intro to" module and be sold on the value prop.
# Here, they're ready to get started building something.

# SCENARIO PATTERN
# Suppose you work at (describe company) that creates (briefly describe what they do.)
# You're building an app that does (something pretty ambitious).
# You're not familiar with (some specific aspect), so you want to build a prototype that
# (does something a bit less ambitious that releates to that one piece.)

# For Azure Cache for Redis, we can talk about some big website the learner is building, and how they need to incorporate server-side caching.
# The learner breaks down the problem and decides to build a script that simulates a pet voting app to get a sense for how the service works.
# When building the scenario, briefly create the mental link as to why this service is the right choice to solve this problem.
# (It integrates with other Azure services, is easy to use, uses the learner's existing knowledge and experience, whatever.)

#
# PROLOG
#

# This name is used to form the unique hostname (Unique across Azure.)
REDIS_NAME="${1:-thpet}"
# If you're running as a script, run: 
# chmod +x redis.sh && ./redis.sh <your-unique-name>
# If you're running one line at a time, run:
# REDIS_NAME="<your-unique-name>"

# This is the resource group name. This will be given to the learner.
RG_NAME=learn-12345

# Create the resource group. The sandbox takes care of this.
az group create --name $RG_NAME --location westus2

#
# EXERCISE 1
#

# Create a directory to work in and move there.
# Not needed for sandbox, but handy for use in your own subscription.
mkdir redis
cd redis

# Create an instance of Azure Cache for Redis. 
# In the module, we use the Azure portal. This is the equivalent CLI command.
az redis create \
  --location westus2 \
  --name $REDIS_NAME \
  --resource-group $RG_NAME \
  --sku Basic \
  --vm-size c0

# I discovered that although `az redis create` returns quickly, it still takes time for the service to come online.
# So spin-wait here until the provisioning state reaches "Succeeded".
# I later found that this module has you do the same thing: https://docs.microsoft.com/en-us/learn/modules/aspnet-session/4-exercise-aspnet-session
# This loop needs a timeout as well so that it doesn't spin forever if something goes wrong.
while true
do
  status=$(az redis show --name $REDIS_NAME --resource-group $RG_NAME --query provisioningState --output tsv)
  if [[ "$status" == "Succeeded" ]]; then
    break
  fi
  printf "Status is '%s'\n" "$status"
  sleep 30
done
printf "Status is '%s'\n" "$status"


# Through the portal, explore some of its features, such as access keys and advanced settings.
# Remind the learner that you can accomplish the same tasks by using the Azure CLI or PowerShell.

#
# EXERCISE 2
#

# Here, we build out the pet voting app. But first, we explore how to do basic 
# queries (CRUD operations) by using the Redis CLI.

# For discussion: There's also a Redis console that I believe is still in preview. Not sure if it les you do all the things 
# you can do from a typical shell environment. But maybe something to explore?
# Update: After thinking about it, I think we should have folks explore the console and at least run PING and maybe do some basic CRUD operations
# (perhaps what we do below). But you can't accomplish the logic we need directly from the console. So we position this as showing the 
# console as a way to get started and perform some basic operations, but to do something more complex, we need the redis-cli and a shell environment.

# Store the hostname as a Bash variable.
# (Exporting variables makes them available to the background processes we run later.)
export REDIS_HOSTNAME=$(az redis show \
  --name $REDIS_NAME \
  --resource-group $RG_NAME \
  --query hostName \
  --output tsv)

# Get the connection port.
export REDIS_PORT=$(az redis show \
  --name $REDIS_NAME \
  --resource-group $RG_NAME \
  --query port \
  --output tsv)

# Get the primary access key.
export REDIS_KEY=$(az redis list-keys \
  --name $REDIS_NAME \
  --resource-group $RG_NAME \
  --query primaryKey \
  --output tsv)
  
# Install the Redis CLI.
# Something to discuss is whether we pin the version (6.2.1) or let it float (discover the latest version dynamically/)
# THere are tradoffs with each approach.
wget https://download.redis.io/releases/redis-6.2.1.tar.gz
tar xzf redis-6.2.1.tar.gz
cd redis-6.2.1
make

# At this point, only the TLS port (6380) is enabled by default.
# The redis-cli doesn't support TLS. We have two configuration choices to use it:
# 1. Enable the non-TLS port (6379) - This in insecure, and will also be deprecated soon. But that's what we'll do here just to get things working.
# 2. Install stunnel. <- What we should probably look into later.

# Enable the non-TLS port (less secure, but enables us to explore.)
az redis update \
  --name $REDIS_NAME \
  --resource-group $RG_NAME \
  --set enableNonSslPort=true

# This is some scratch code to install stunnel. Not sure how to compile it yet.
# cd ..
# wget https://www.stunnel.org/downloads/stunnel-5.58.tar.gz
# tar xzf stunnel-5.58.tar.gz
# cd stunnel-5.58
# make???

# Note: from here, this is just standard Redis. In other words, if you're already a Redis CLI user,
# this will be familiar to you already.
# Note: Handy reference for all Redis CLI commands: https://redis.io/commands/

# Show how to connect to the Redis console interactively.
# The following line is commented because it drops you into an interactive session, but try it.
# src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY

# From the interactive session:
# * Run `PING`. The Redis server responds with "PONG".
# * Run `exit` to leave the Redist prompt.

# Now let's switch over to automating interactions. This is a progression that builds up 
# to performing basic CRUD operations.

# Run the Same PING commd, but non-interactively.
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY PING 
# Run the same command, but suppress warning message.
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY PING 2> /dev/null

# (C)reate a basic key/value pair
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY SET "cats" 42 2> /dev/null
# > OK

# (R)ead back the same key/value pair
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY GET "cats" 2> /dev/null
# > "42"

# Read all keys
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY --scan 2> /dev/null
# > cats

# (U)pdate the same value by overwriting it.
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY SET "cats" 60 2> /dev/null
# > "OK"

# (U)pdate the same value by incrementing it by 12.
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY INCRBY "cats" 12 2> /dev/null
# > (integer) 72

# (D)elete the key
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY DEL "cats" 2> /dev/null
# > (integer) 1

# Verify that it's gone (1 means it exists; 0 means it doesn't)
src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY EXISTS "cats" 2> /dev/null
# > (integer) 0

# OK, now that we have a handle on the basic commands, let's build a basic pet voting system.
# Consider whether we break this into a second knowledge/exercise unit pair.

# These are the pets you can vote for.
export pets=( cats dogs fish reptiles )

# Set all votes to 0
for pet in "${pets[@]}"; do
  src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY SET $pet 0 2> /dev/null    
done

# This function simulates voting (write operations.) It loops forever and increments each 
# vote count by a random value (multiplied by some weight.)
simulate_voting () {
  # These are the weights.
  # This makes the output more realistic (we would expect more votes for dogs than fist.)
  # This is called an assocaitive array in Bash. You might call it a map or hash.
  declare -A weights
  weights["cats"]=3
  weights["dogs"]=4
  weights["fish"]=2
  weights["reptiles"]=1

  while true; do 
    for pet in "${pets[@]}"; do
      # Note we use INCRBY.
      # Multiply by a number in the range [0, 99] and mutiply by the weight.
      src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY INCRBY $pet $(($RANDOM % 100 * ${weights["$pet"]}))
    done
    sleep 1
  done
}

# This function simulates vote tallying (read operations.) It loops forever and prints the current results.
display_results () {
  while true; do
    declare -A votes
    total_votes=0
    # Tally the current vote count for each pet and the overall number of votes.
    for pet in "${pets[@]}"; do
      temp=$(src/redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_KEY GET "$pet")
      votes["$pet"]=$temp
      (( total_votes += temp ))
    done
    # Compute the percentage of votes for each kind of pet.
    # Write results to file so that we can easily print them as a table.
    rm /tmp/scratch.txt
    for pet in "${pets[@]}"; do
      percent=$(( 100 * ${votes["$pet"]} / $total_votes ))
      printf "%s: %d (%s%%)\n" "$pet" ${votes["$pet"]} "$percent" >> /tmp/scratch.txt
    done
    # Print the vote total in the footer.
    printf "========= ===== ======\n" >> /tmp/scratch.txt
    printf "total: %d (100%%)\n" "$total_votes" >> /tmp/scratch.txt
    # Clear the terminal and print the totals. The column utility makes the results look pretty.
    clear
    cat /tmp/scratch.txt | column -t
    sleep 1
  done
}

# Run the simulation (writes + reads) in parallel, in the background, for 1 minute.
simulate_voting 1>vote.log 2>/dev/null &
display_results 2>/dev/null &
sleep 60

# Terminate the background tasks.
kill -9 $(jobs -p)

# Examine the final vote tally. You see something like this:

# cats:      6834   (30%)
# dogs:      8976   (40%)
# fish:      4030   (18%)
# reptiles:  2345   (10%)
# =========  =====  ======
# total:     22185  (100%)

# You're confident that things are working because these numbers (the weights) make sense.
# Dogs got about 2x the votes as fish, and 4x the votes as reptiles.

#
# EXERCISE 3
#

# Here, the learner explores some of the management capabilties.
# I don't have a scenario in mind yet, but there's some CLI surface area around management that we
# haven't yet touched.
# That or split exercise 2 into two pieces - exploring basic CRUD operations with redis-cli and then building the pet voting app.

#
# Cleanup
#

# The learner won't need to clean anything up, but here's how to delete the RG.
az group delete --name $RG_NAME --yes
cd ..
rm -rf redis

# After thinkng about this a bit, I think the exercises will "depend" on a few things - 
# * A dev audience might want to work more with the actual service. That's why I think here we might want to break up the exercise
# and skip the part about managing it?
# * But perhaps sprinkle in management tasks (for example, enabling the TLS port) as they're needed.
# * That said, we really didn't identify up front whether this is for developers or admins. (I think it's for developers.)
