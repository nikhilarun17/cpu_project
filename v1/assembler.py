def parse_value(tok):
    if len(tok) == 3 and tok[0] == "'" and tok[2] == "'":
        return ord(tok[1])   # character literal, e.g. 'H' -> 72
    else:
        return int(tok)       # plain number, e.g. 72 -> 72

with open("input.txt", "r") as f:
    lines = f.read().splitlines()  # splits on \n and drops it automatically
lines = [line.split(";")[0].strip() for line in lines]
lines = [line for line in lines if line]
lines = [line.replace(",", "") for line in lines]
label_names = []
labels = {}
address = 1  # address 0 is reserved for the "LI r14, 255" preamble
for i in range(len(lines)):
    line = lines[i]
    if line.endswith(":"):
        label_names.append(line[:-1])
for i in range(len(lines)):
    line = lines[i]
    if line[:-1] in label_names:
        labels[line[:-1]] = address
    elif line.startswith("JMP"):
        if line.split()[1] in label_names:
            address += 2
        else:
            address += 1   
    elif line.startswith("JZ"):
        if line.split()[2] in label_names:
            address += 2
        else:
            address += 1
    elif line.startswith("STORE"):
        address += 1
    else:
        address += 1
address = 0
assembly_names = {"ADD": "0000", "SUB": "0001", "AND": "0010", "OR": "0011", "XOR": "0100", "NOT": "0101", "LT": "0110", "EQ": "0111"}
binary_lines = []
binary_lines.append("mem[{}] = 1100".format(address) + "1110" + "11111111")  # LI r14, 255
address += 1

for i in range(len(lines)):
    line = lines[i]
    if line.endswith(":"):
        continue
    elif line.startswith("JMP"):
        if line.split()[1] in labels:
            binary_lines.append("mem[{}] = 11001111".format(address) + format(labels[line.split()[1]], '08b'))
            address += 1
            binary_lines.append("mem[{}] = 1010000011110000".format(address))
            address += 1
        else:
            binary_lines.append("mem[{}] = 10100000".format(address) + format(int(line.split()[1].lstrip('r')), '04b')+"0000")
            address += 1    
    elif line.startswith("JZ"):
        if line.split()[2] in labels:
            binary_lines.append("mem[{}] = 11001111".format(address) + format(labels[line.split()[2]], '08b'))
            address += 1
            binary_lines.append("mem[{}] = 10110000{}1111".format(address, format(int(line.split()[1].lstrip('r')), '04b')))
            address += 1
        else:
            binary_lines.append("mem[{}] = 10110000".format(address) + format(int(line.split()[1].lstrip('r')), '04b') + format(int(line.split()[2].lstrip('r')), '04b'))
            address += 1
    elif line.split()[0] in assembly_names:
        binary_lines.append("mem[{}] = {}".format(address, assembly_names[line.split()[0]] + format(int(line.split()[1].lstrip('r')), '04b') + format(int(line.split()[2].lstrip('r')), '04b'))+ format(int(line.split()[3].lstrip('r')), '04b'))
        address += 1
    elif line.startswith("LI"):
        binary_lines.append("mem[{}] = 1100".format(address) + format(int(line.split()[1].lstrip('r')), '04b') + format(parse_value(line.split()[2]), '08b'))
        address += 1
    elif line.startswith("STORE"):
        binary_lines.append("mem[{}] = 1001".format(address) + "0000" + format(int(line.split()[1].lstrip('r')), '04b') + "1110")
        address += 1

with open("program_init.v", "w") as f:
    for line in binary_lines:
        prefix, bits = line.split("= ")
        f.write("{}= 16'b{};\n".format(prefix, bits))