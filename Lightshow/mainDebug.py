usr_in = ""

while usr_in != "-1":
    usr_in = input("")

    with open('/Users/mattia/Desktop/out.txt', 'a') as file:
    # Write a string to the file
        file.write(usr_in + "\n")
