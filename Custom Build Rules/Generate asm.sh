#  Copyright (c) 2012, Stefan Johnson                                                  
#  All rights reserved.                                                                
#                                                                                      
#  Redistribution and use in source and binary forms, with or without modification,    
#  are permitted provided that the following conditions are met:                       
#                                                                                      
#  1. Redistributions of source code must retain the above copyright notice, this list 
#     of conditions and the following disclaimer.                                      
#  2. Redistributions in binary form must reproduce the above copyright notice, this   
#     list of conditions and the following disclaimer in the documentation and/or other
#     materials provided with the distribution.                                        
#  
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

cd "$INPUT_FILE_DIR"
as "$INPUT_FILE_NAME" -o "$DERIVED_SOURCES_DIR/$INPUT_FILE_BASE.o" $(head -n 1 "$INPUT_FILE_NAME" | awk '{ print substr($0,3) }')

#Would be better to not use ruby, but I'm not knowledgeable enough of how to do similar text processing with just the command line.
#Also need to find out how to display errors from here to Xcode so it can display them
ruby -e '
code = ".test\n"
bytes = ARGV[1].split("\n").map! { |i| i.split(" ").drop(1) }.flatten
symbols = ARGV[0].split("\n")
symbols.each_with_index { |sym, i|
s = sym.split(" ")
name = s[0]
addr = s[2].to_i

b = bytes[addr,symbols.count > i + 1 ? symbols[i+1].split(" ")[2].to_i : bytes.count - addr].join(",0x")
code << ".globl #{name}\n#{name}:\n" << (b.length > 0 ? ".byte 0x#{b}\n" : "" )
}

File.open(ARGV[2], "w") { |src| src << code }' "$(nm -s __TEXT __text -n -g -P -t d $DERIVED_SOURCES_DIR/$INPUT_FILE_BASE.o)" "$(otool -X -s __TEXT __text $DERIVED_SOURCES_DIR/$INPUT_FILE_BASE.o)" "$DERIVED_SOURCES_DIR/$INPUT_FILE_NAME.s"
