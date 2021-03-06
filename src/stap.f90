! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                       .
! .                            S T A P 9 0                                .
! .                                                                       .
! .     AN IN-CORE SOLUTION STATIC ANALYSIS PROGRAM IN FORTRAN 90         .
! .     Adapted from STAP (KJ Bath, FORTRAN IV) for teaching purpose      .
! .                                                                       .
! .     Xiong Zhang, (2013)                                               .
! .     Computational Dynamics Group, School of Aerospace                 .
! .     Tsinghua Univerity                                                .
! .                                                                       .
! . . . . . . . . . . . . . .  . . .  . . . . . . . . . . . . . . . . . . .
PROGRAM STAP90

  USE GLOBALS
  USE MEMALLOCATE

  IMPLICIT NONE
  INTEGER :: NEQ1, NLOAD, MM
  INTEGER :: LL, I
  INTEGER :: TT
! OPEN INPUT DATA FILE, RESULTS OUTPUT FILE AND TEMPORARY FILES
  CALL OPENFILES()
  MAXEST=0

! * * * * * * * * * * * * * * * * * * * * * *
! *              INPUT PHASE                *
! * * * * * * * * * * * * * * * * * * * * * *

  WRITE(*,'("Input phase ... ")')

  CALL SECOND (TIM(1))

! Read control information

!   HED    - The master heading informaiton for use in labeling the output
!   NUMNP  - Total number of nodal points
!            0 : program stop
!   NUMEG  - Total number of element group (>0)
!   NLCASE - Number of load case (>0)
!   MODEX  - Solution mode
!            0 : data check only;
!            1 : execution

  READ (IIN,'(A80,/, 4I1,/,4I10)') HED, &
                                  BANDWIDTHOPT,PARDISODOOR,LOADANALYSIS,DYNANALYSIS, &
                                  NUMNP,NUMEG,NLCASE,MODEX
! input node
  IF (NUMNP.EQ.0) STOP   ! Data check mode

  WRITE (IOUT,"(/,' ',A80,//,  &
     ' C O N T R O L   I N F O R M A T I O N',//,  &
     '      NUMBER OF NODAL POINTS',10(' .'),' (NUMNP)  = ',I10,/,   &
     '      NUMBER OF ELEMENT GROUPS',9(' .'),' (NUMEG)  = ',I10,/,  &
     '      NUMBER OF LOAD CASES',11(' .'),' (NLCASE) = ',I10,/,     &
     '      SOLUTION MODE ',14(' .'),' (MODEX)  = ',I10,/,           &
     '         EQ.0, DATA CHECK',/,   &
     '         EQ.1, EXECUTION')") HED,NUMNP,NUMEG,NLCASE,MODEX

! Read nodal point data
! ALLOCATE STORAGE
!   ID(6,NUMNP) : Boundary condition codes (0=free,1=deleted)
!   IDBEAM(6,NUMNP) : Boundary condition codes for beam (0=free,1=fixed)
!   X(NUMNP)    : X coordinates
!   Y(NUMNP)    : Y coordinates
!   Z(NUMNP)    : Z coordinates

  DIM = 6
  
  CALL MEMALLOC(1,"ID   ",DIM*NUMNP,1)  !OTHER SITUATIONS EXCEPT BEAM (THE FORMER ONE)
    
  CALL MEMALLOC(2,"X    ",NUMNP,ITWO)
  CALL MEMALLOC(3,"Y    ",NUMNP,ITWO)
  CALL MEMALLOC(4,"Z    ",NUMNP,ITWO)

  CALL INPUT (IA(NP(1)),DA(NP(2)),DA(NP(3)),DA(NP(4)),NUMNP,NEQ)

! Calculate and store load vectors
!   R(NEQ) : Load vector

  CALL MEMALLOC(5,"R    ",NEQ,ITWO)

  WRITE (IOUT,"(//,' L O A D   C A S E   D A T A')")

  REWIND ILOAD

  DO CURLCASE=1,NLCASE

!    LL    - Load case number
!    NLOAD - The number of concentrated loads applied in this load case

     READ (IIN,'(2I10)') LL,NLOAD

     WRITE (IOUT,"(/,'     LOAD CASE NUMBER',7(' .'),' = ',I10,/, &
                     '     NUMBER OF CONCENTRATED LOADS . = ',I10)") LL,NLOAD

     IF (LL.NE.CURLCASE) THEN
        WRITE (IOUT,"(' *** ERROR *** LOAD CASES ARE NOT IN ORDER')")
        STOP
     ENDIF

!    Allocate storage
!       NOD(NLOAD)   : Node number to which this load is applied (1~NUMNP)
!       IDIRN(NLOAD) : Degree of freedom number for this load component
!                      1 : X-direction;
!                      2 : Y-direction;
!                      3 : Z-direction
!       FLOAD(NLOAD) : Magnitude of load

     CALL MEMALLOC(6,"NOD  ",NLOAD,1)
     CALL MEMALLOC(7,"IDIRN",NLOAD,1)
     CALL MEMALLOC(8,"FLOAD",NLOAD,ITWO)
     
     CALL LOADS (DA(NP(5)),IA(NP(6)),IA(NP(7)),DA(NP(8)),IA(NP(1)),NLOAD,NEQ) !OTHER SITUATIONS EXCEPT BEAM(THE FORMER ONE)

  END DO
  
! * * * * * * * * * * * * * * * * * * * * * *
! *               SOLUTION PHASE            *
! * * * * * * * * * * * * * * * * * * * * * *  

WRITE(*,'("Solution phase ... ")')
IND=1    ! Read and generate element information

CALL MEMFREEFROM(5)
CALL MEMALLOC(5,"MHT  ",NEQ,1)                  !if (.NOT. PARDISODOOR)
CALL ELCAL ! 到这里2,3,4才没用的
CALL VTKgenerate (IND)        !Prepare Post-Processing Files.

! ********************************************************************8
! Read, generate and store element data
! 从这里开始，用不用pardiso会变得很不一样
! Clear storage
!   MHT(NEQ) - Vector of column heights

if(.not. pardisodoor) then
  CALL SECOND (TIM(2)) 
! ALLOCATE STORAGE
!    MAXA(NEQ+1)
  CALL MEMFREEFROM(7)
  CALL MEMFREEFROMTO(2,4)
  CALL MEMALLOC(2,"MAXA ",NEQ+1,1)
  CALL ADDRES (IA(NP(2)),IA(NP(5)))
  CALL SECOND (TIM(3))
! ALLOCATE STORAGE
!    A(NWK) - Global structure stiffness matrix K
!    R(NEQ) - Load vector R and then displacement solution U
 
  MM=NWK/NEQ
  CALL MEMALLOC(3,"STFF ",NWK,ITWO)
  CALL MEMALLOC(4,"R    ",NEQ,ITWO)
  CALL MEMALLOC(11,"ELEGP",MAXEST,1)

! Write total system data

  WRITE (IOUT,"(//,' TOTAL SYSTEM DATA',//,   &
                   '     NUMBER OF EQUATIONS',14(' .'),'(NEQ) = ',I10,/,   &
                   '     NUMBER OF MATRIX ELEMENTS',11(' .'),'(NWK) = ',I10,/,   &
                   '     MAXIMUM HALF BANDWIDTH ',12(' .'),'(MK ) = ',I10,/,     &
                   '     MEAN HALF BANDWIDTH',14(' .'),'(MM ) = ',I10)") NEQ,NWK,MK,MM
! ***************************************************************************************
else !如果使用pardiso
  CALL MEMFREEFROMTO(2,4)
  ! NP(2,3,4,5)均在这里被分配
  CALL pardiso_input(IA(NP(1)))
  CALL SECOND (TIM(3))
  CALL MEMALLOC(11,"ELEGP",MAXEST,1)
! Write total system data
end if

IF (DYNANALYSIS .EQV. .TRUE.) call prepare_MassMatrix

! In data check only mode we skip all further calculations
  IF (MODEX.LE.0) THEN
     CALL SECOND (TIM(4))
     CALL SECOND (TIM(5))
     CALL SECOND (TIM(6))
  ELSE
     IND=2    ! Assemble structure stiffness matrix
     WRITE(*,'("Begin assembling ")')
     CALL ASSEM (A(NP(11)))
     WRITE(*,'("End   assembling ")')
     CALL SECOND (TIM(4))
     IF (DYNANALYSIS .EQV. .TRUE.) CALL EIGENVAL (DA(NP(3)), DA(NP(10)), IA(NP(2)), NEQ, NWK, NEQ+1, 2)
     if(pardisodoor) then
        if (.not. DYNANALYSIS) then
            WRITE(*,'("Begin cropping ")')
            if(huge) then
                call pardiso_crop(stff, IA(NP(2)), columns)
            else
                call pardiso_crop(DA(NP(3)), IA(NP(2)), IA(NP(5)))          ! Condensing CSR format sparse matrix storage: deleting zeros
            end if
            WRITE(*,'("End   cropping ")')
        end if
    else
        !    Triangularize stiffness matrix
        NEQ1 = NEQ+1
        CALL COLSOL (DA(NP(3)),DA(NP(4)),IA(NP(2)),NEQ,NWK,NEQ1,1)
     end if
     
      
     IND=3    ! Stress calculations

     REWIND ILOAD
     CALL SECOND (TIM(5))
     DO CURLCASE=1,NLCASE
        CALL LOADV (DA(NP(4)),NEQ)   ! Read in the load vector
        if(pardisodoor) then
            WRITE (IOUT,"(//,' TOTAL SYSTEM DATA',//,   &
                   '     NUMBER OF EQUATIONS',14(' .'),'(NEQ) = ',I10,/,   &
                   '     NUMBER OF MATRIX ELEMENTS',11(' .'),'(NWK) = ',I9)") NEQ,NWK
            if(huge) then
                call pardiso_solver(stff,DA(NP(4)),IA(NP(2)), columns)
                deallocate(stff)
                deallocate(columns)
            else
                call pardiso_solver(DA(NP(3)),DA(NP(4)),IA(NP(2)), IA(NP(5)))
            end if
        else
!       Solve the equilibrium equations to calculate the displacements
            IF (LOADANALYSIS .EQV. .TRUE.) CALL COLSOL (DA(NP(3)),DA(NP(4)),IA(NP(2)),NEQ,NWK,NEQ1,2)
        end if
        CALL SECOND (TIM(6))
        WRITE (IOUT,"(//,' LOAD CASE ',I3)") CURLCASE
        
        CALL WRITED (DA(NP(4)),IA(NP(1)),NEQ,NUMNP)  ! PRINT DISPLACEMENTS FOR OTHER SITUATIONS(THE FORMER ONE)
!           Calculation of stresses
            CALL STRESS (A(NP(11)))
            CALL SECOND (TIM(7))
     END DO
     
!!!!!!!!!!!!!!!!!PLASTIC ONLY!!!!!!!!!!!!
     IF ( (HED .EQ. 'PLASTIC') .AND. ( .NOT. PLASTICTRIAL ) .AND. (PLASTICITERATION) ) THEN
        GOTO 1000 
     ENDIF
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
     
     CALL VTKgenerate (IND)
     
  END IF

 !!!!!!!!!!!!!!FOR PLASTIC TRUSS ONLY!!!!!!!!!!!!!!!!!!!

1000 IF ( (HED .EQ. 'PLASTIC') .AND. ( .NOT. PLASTICTRIAL ) .AND. (PLASTICITERATION) ) THEN
        CALL PLASTIC
     ENDIF
  
 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
  
! Print solution times

  TT=0
  DO I=1,6
     TIM(I)=TIM(I+1) - TIM(I)
     TT=TT + TIM(I)
  END DO
  TT = TT - TIM(1)
  WRITE (IOUT,"(//,  &
     ' S O L U T I O N   T I M E   L O G   I N   S E C',//,   &
     '     TIME FOR INPUT PHASE ',14(' .'),' =',I10,/,     &
     '     TIME FOR PREPARATION OF MATRIX FORMAT . . . . . . =',I10,/,     &
     '     TIME FOR ASSEMBLING . . . . . . . . . . . . . . . =',I10, /,   &
     '     TIME FOR FACTORIZATION OF STIFFNESS MATRIX  . . . =',I10, /,   &
     '     TIME FOR LOAD CASE SOLUTIONS ',10(' .'),' =',I10,/,   &
     '     TIME FOR CALCLUATE STRESS',12(' .'),' =',I10,//,   &
     'T O T A L   S O L U T I O N   T I M E  . . . . . . . . =',I10)") (TIM(I),I=1,6),TT

  WRITE (*,"(//,  &
     ' S O L U T I O N   T I M E   L O G   I N   S E C',//,   &
     '     TIME FOR INPUT PHASE ',14(' .'),' =',I10,/,     &
     '     TIME FOR PREPARATION OF MATRIX FORMAT . . . . . . =',I10,/,     &
     '     TIME FOR ASSEMBLING . . . . . . . . . . . . . . . =',I10, /,   &
     '     TIME FOR FACTORIZATION OF STIFFNESS MATRIX  . . . =',I10, /,   &
     '     TIME FOR LOAD CASE SOLUTIONS ',10(' .'),' =',I10,/,   &
     '     TIME FOR CALCLUATE STRESS',12(' .'),' =',I10,//,   &
     'T O T A L   S O L U T I O N   T I M E  . . . . . . . . =',I10)") (TIM(I),I=1,6),TT
     
  CALL CLOSEFILES()
  !write (*,*) "Press Any Key to Exit..."
  !read (*,*)
  STOP

END PROGRAM STAP90


SUBROUTINE SECOND (TIM)
! USE DFPORT   ! Only for Compaq Fortran
  IMPLICIT NONE
  character*8 date
  character*10 time
  character*5 zone
  integer*4 values(8)
  integer :: TIM
  call DATE_AND_TIME(date, time, zone, values)
  TIM = values(7)*1000+values(8)+values(6)*60000

! This is a Fortran 95 intrinsic subroutine
! Returns the processor time in seconds


  RETURN
END SUBROUTINE SECOND


SUBROUTINE WRITED (DISP,ID,NEQ,NUMNP)

! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   To PRINT DISPLACEMENT AND ANGLES                                          .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS, ONLY : IOUT, VTKTmpFile, CURLCASE

  IMPLICIT NONE
  INTEGER :: NEQ,NUMNP,ID(6,NUMNP)
  REAL(8) :: DISP(NEQ),D(6)
  INTEGER :: IC,II,I,KK,IL
  character(len=25) :: String

! Print displacements

  WRITE (IOUT,"(//,' D I S P L A C E M E N T S',//,'  NODE ',3X,   &
                    'X-DISPLACEMENT  Y-DISPLACEMENT  Z-DISPLACEMENT  X-ROTATION  Y-ROTATION  Z-ROTATION')")

  IC=4

  write(String, "('Displacement_Load_Case',I2.2)") CURLCASE
  write (VTKTmpFile) String, 3, NUMNP
  
  DO II=1,NUMNP
     IC=IC + 1
     IF (IC.GE.56) THEN
        WRITE (IOUT,"(//,' D I S P L A C E M E N T S',//,'  NODE ',3X,   &
                          'X-DISPLACEMENT   Y-DISPLACEMENT  Z-DISPLACEMENT  X-ROTATION  Y-ROTATION  Z-ROTATION')")
        IC=4
     END IF

     DO I=1,6
        D(I)=0.
     END DO

     DO I=1,6
        KK=ID(I,II)
        IF (KK.NE.0) D(I)=DISP(KK)
     END DO

     WRITE (IOUT,'(1X,I10,5X,6E14.6)') II,D
     write (VTKTmpFile) D(1:3)                                    !Displacements

  END DO
  
  RETURN

END SUBROUTINE WRITED


SUBROUTINE OPENFILES()
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   Open input data file, results output file and temporary files   .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS
! use DFLIB ! for NARGS()  ! Only for Compaq Fortran

  IMPLICIT NONE
  LOGICAL :: EX
  CHARACTER*80 FileInp
  integer :: i

! Only for Compaq Fortran
! if(NARGS().ne.2) then
!    stop 'Usage: mpm3d InputFileName'
!  else
!    call GETARG(1,FileInp)
!  end if

  if(COMMAND_ARGUMENT_COUNT().ne.1) then
     stop 'Usage: STAP90 InputFileName'
  else
     call GET_COMMAND_ARGUMENT(1,FileInp)
  end if

  INQUIRE(FILE = FileInp, EXIST = EX)
  IF (.NOT. EX) THEN
     PRINT *, "*** STOP *** FILE STAP90.IN DOES NOT EXIST !"
     STOP
  END IF
  
  do i = 1, len_trim(FileInp)
    if (FileInp(i:i) .EQ. '.') exit
  end do
  
  OPEN(IIN   , FILE = FileInp,  STATUS = "OLD")
  OPEN(IOUT  , FILE = FileInp(1:i-1)//".OUT", STATUS = "REPLACE")
  OPEN(IELMNT, FILE = "ELMNT.TMP",  FORM = "UNFORMATTED")
  OPEN(ILOAD , FILE = "LOAD.TMP",   FORM = "UNFORMATTED")
  OPEN(VTKFile, FILE = FileInp(1:i-1)//".OUT.vtk", STATUS = "REPLACE")
  OPEN(VTKTmpFile, File = "VTK.tmp", FORM = "UNFORMATTED", STATUS = "REPLACE")
  OPEN(VTKNodeTmp, FILE = "VTKNode.tmp", FORM = "UNFORMATTED", STATUS = "REPLACE")
  OPEN(VTKElTypTmp, FILE = "VTKElTyp.tmp", FORM = "UNFORMATTED", Access='Stream', STATUS = "REPLACE") !FORM = "UNFORMAED",
  
END SUBROUTINE OPENFILES


SUBROUTINE CLOSEFILES()
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
! .                                                                   .
! .   Close all data files                                            .
! . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

  USE GLOBALS
  IMPLICIT NONE
  CLOSE(IIN)
  CLOSE(IOUT)
  CLOSE(IELMNT, status='delete')
  CLOSE(ILOAD, status='delete')
  close(VTKFile)
  close(VTKTmpFile, status='delete')
  close(VTKNodeTmp, status='delete')
  close(VTKElTypTmp, status='delete')
  
  !FOR PLASTIC TRUSS ONLY
  IF (HED .EQ. 'PLASTIC') THEN
   CLOSE(PRESENTDISPLACEMENT, STATUS = 'DELETE')
   CLOSE(DELTALOAD, STATUS = 'DELETE')
   CLOSE(PRESENTSTRESS, STATUS = 'DELETE')
  ENDIF
  
END SUBROUTINE CLOSEFILES
