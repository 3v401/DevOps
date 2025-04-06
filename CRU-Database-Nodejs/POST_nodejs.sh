#!/bin/bash

while true; do
  printf "\nWhat do you want to do?\n"
  printf "(0) Terminate program, (1) Create item, (2) Return specific product, (3) Return all products, (4) Update product, (5) Delete product: \n"
  read -p "Command:" command

  # If option 1 introduced:
  # Create item:

  if [ "$command" -eq 1 ]; then
    read -p "Enter Model_name (string): " PARAMETER1
    read -p "Enter Price USD (integer): " PARAMETER2
    read -p "Is the car returned? (string): " PARAMETER3
    read -p "Status of the car (string): " PARAMETER4
    echo "Creating a new product..."
    curl -X POST http://<IP>:3000/api/products \
        -H "Content-Type: application/json" \
      -d "{
        \"Model_name\": \"${PARAMETER1}\",
        \"Price\": ${PARAMETER2},
        \"Returned\": \"${PARAMETER3}\",
        \"Status\": \"${PARAMETER4}\"
      }"
  # If option 2 introduced:
  # Return specific product
  elif [ "$command" -eq 2 ]; then
    read -p "Enter product ID: " ID
    echo "Returning product... "
    curl -X GET http://<IP>:3000/api/products/${ID}

  # If option 3 introduced:
  # Return all elements (read)
  elif [ "$command" -eq 3 ]; then
    echo "Returning all products... "
    curl -X GET http://<IP>:3000/api/products

  # If option 4 introduced:
  # Update:
  # Define {ID} as input
  elif [ "$command" -eq 4 ]; then
    read -p "Enter product ID: " ID
    read -p "Enter Model_name (string): " PARAMETER1
    read -p "Enter Price USD (integer): " PARAMETER2
    read -p "Is the car returned? (string): " PARAMETER3
    read -p "Status of the car (string): " PARAMETER4
    echo "Updating product ID: ${ID}... "
    curl -X PUT http://<IP>:3000/api/products/${ID} \
      -H "Content-Type: application/json" \
      -d "{
        \"Model_name\": \"${PARAMETER1}\",
        \"Price\": ${PARAMETER2},
        \"Returned\": \"${PARAMETER3}\",
        \"Status\": \"${PARAMETER4}\"
      }"

  # If option 5 introduced:
  # Delete:
  # Define {ID} as input
  elif [ "$command" -eq 5 ]; then
    read -p "Enter product ID: " ID
    curl -X DELETE http://<IP>:3000/api/products/${ID}
    echo "Deleted product with ID: ${ID}."

  elif [ "$command" -eq 0 ]; then
    echo "Terminating program."
    exit 0

  else
    echo "Invalid option, introduce number between [1,5] "
  fi
done
