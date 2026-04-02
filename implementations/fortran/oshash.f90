! OpenSubtitles Hash (OSHash) - Fortran implementation.
! Algorithm: file_size + sum_le_u64(first_64KB) + sum_le_u64(last_64KB)
program oshash
    implicit none
    integer, parameter :: chunk_size = 65536
    integer(8) :: hash, fsize, val
    integer :: i, u, ios
    character(len=256) :: filepath

    if (command_argument_count() < 1) then
        write(0, '(A)') 'Usage: oshash <file>'
        stop 1
    end if
    call get_command_argument(1, filepath)

    ! Get file size
    inquire(file=trim(filepath), size=fsize)
    hash = fsize

    open(newunit=u, file=trim(filepath), access='stream', form='unformatted', &
         status='old', iostat=ios)
    if (ios /= 0) then
        write(0, '(A)') 'Error opening file'
        stop 1
    end if

    ! Hash first 64KB
    do i = 1, chunk_size / 8
        read(u) val
        hash = hash + val
    end do

    ! Hash last 64KB
    read(u, pos=max(1_8, fsize - chunk_size + 1))
    do i = 1, chunk_size / 8
        read(u) val
        hash = hash + val
    end do

    close(u)

    ! Print hash - Fortran outputs uppercase hex, convert via ichar trick
    block
        character(len=16) :: hex_str
        integer :: j
        write(hex_str, '(Z16.16)') hash
        do j = 1, 16
            if (ichar(hex_str(j:j)) >= ichar('A') .and. ichar(hex_str(j:j)) <= ichar('F')) then
                hex_str(j:j) = char(ichar(hex_str(j:j)) + 32)
            end if
        end do
        write(*, '(A)') hex_str
    end block
end program oshash
