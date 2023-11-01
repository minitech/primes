MEMORY
{
    flash : ORIGIN = 0, LENGTH = 256K
    ram : ORIGIN = 0x20000000, LENGTH = 8K
}

SECTIONS
{
    .data : { *(.data) } > ram
}
