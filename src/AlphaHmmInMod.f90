!-----------------------------------------------------------------------------------------------------------------------
! The Roslin Institute, The University of Edinburgh - AlphaGenes Group
!-----------------------------------------------------------------------------------------------------------------------
!
! MODULE:       AlphaHmmInMod
!
!> @file        AlphaHmmInMod.f90
!
! DESCRIPTION:
!> @brief       Module holding input parameters
!>
!> @details     This MODULE contains a class which contains all input parameters read in from a spec file.
!> It also contains the default container object for the spec file, defaultInput.
!
!> @author      Roberto Antolin, roberto.antolin@roslin.ed.ac.uk
!
!> @date        May 10, 2017
!
!> @version     0.0.1 (alpha)
!
! REVISION HISTORY:
! 2017.05.10  RAntolin - Initial Version
!
!-----------------------------------------------------------------------------------------------------------------------
module AlphaHmmInMod
    use iso_fortran_env

    type AlphaHmmInput

    ! character(len=300) :: PedigreeFile = "Pedigree.txt"     ! Pedigree File
    character(len=300) :: PedigreeFile = "Pedigree.txt"
    character(len=300) :: GenotypeFile="Genotypes.txt"
    character(len=300) :: TrueGenotypeFile="TrueGenotypes.txt"
    character(len=300) :: GenderFile="None"
    character(len=300) :: InbredAnimalsFile="None"
    character(len=300) :: HapListFile="None"
    character(len=300) :: PriorAllFreqsFile="None"

    integer(kind=1) :: HMMOption                            ! Type of HMM imputation (Genotype vs Sequence)

    integer(kind=int32) :: nSnp                             ! Number of SNPs to process in the hmm algorithm
    integer(kind=int32) :: nHapInSubH                       ! Number of haplotypes
    integer(kind=int32) :: HmmBurnInRound                   ! Number of burnin rounds of the MCMC
    integer(kind=int32) :: nRoundsHmm                       ! Number of rounds of the MCMC
    integer(kind=int32) :: useProcs                         ! Number of threads to be used
    real(kind=real32) :: imputedThreshold                   !< threshold of imputed snps
    real(kind=real32) :: phasedThreshold                   !< threshold of phase information accept

    integer :: AnimalFileUnit, prePhasedFileUnit, pedigreeFileUnit,genotypeFileUnit,GenderFileUnit,HapListUnit,PriorAllFreqsUnit
    integer(kind=int32) :: seed
    logical :: HapList=.FALSE.
    logical :: PriorAllFreqs = .FALSE.

    contains
        procedure :: ReadInParameterFile
    end type AlphaHmmInput

    type(AlphaHmmInput),target, allocatable :: defaultInput

contains
    !---------------------------------------------------------------------------
    ! DESCRIPTION:
    !> @brief      Constructor for AlphaHmmInput object
    !
    !> @author     Roberto Antolin, roberto.antolin@roslin.ed.ac.uk
    !
    !> @date       May 10, 2017
    !
    ! PARAMETERS:
    !> @param[in]  specfile - The path of the specfile
    !---------------------------------------------------------------------------

    subroutine ReadInParameterFile(this,SpecFile)
        use AlphaHouseMod, only: parseToFirstWhitespace,splitLineIntoTwoParts,toLower
        use hmmPARAMETERS

        integer :: unit,IOStatus
        character(len=*), intent(in) :: SpecFile
        class(AlphaHmmInput), optional, intent(inout),target :: this

        character(len=300) :: first, line
        character(len=:), allocatable::tag
        character(len=300),dimension(:),allocatable :: second
        logical :: exists


        open(newunit=unit, file=SpecFile, action="read", status="old")
        IOStatus = 0
        this%imputedThreshold = 100
        READFILE: do while (IOStatus==0)
            read(unit,"(A)", IOStat=IOStatus)  line
            if (len_trim(line)==0) then
                CYCLE
            end if

            call splitLineIntoTwoParts(trim(line), first, second)
            tag = parseToFirstWhitespace(first)
            if (first(1:1)=="=" .or. len(trim(line))==0) then
                cycle
            else
                select case(trim(tag))

                ! case("pedigreefile")
                !     if (.not. allocated(second)) then
                !         write(*, "(A,A)") "No pedigree file specified. Using default filename: ", this%PedigreeFile
                !     else
                !         write(this%PedigreeFile, "(A)") second(1)
                !     end if

                case("genotypefile")
                    if (.not. allocated(second)) then
                        write(*, "(A,A)") "No genotype file specified. Using default filename: ", this%Genotypefile
                    else
                        write(this%Genotypefile, "(A)") second(1)
                    endif

                case("numbersnp")
                    read(second(1),*) this%nsnp

                case("hmmoption")
                    this%hmmoption=RUN_HMM_NULL
                    if (toLower(trim(second(1)))=='no') this%hmmoption=RUN_HMM_NO
                    if (toLower(trim(second(1)))=='yes') this%hmmoption=RUN_HMM_YES
                    if (toLower(trim(second(1)))=='only') this%hmmoption=RUN_HMM_ONLY
                    if (toLower(trim(second(1)))=='Prephase') this%hmmoption=RUN_HMM_PREPHASE
                    if (toLower(trim(second(1)))=="ngs") this%hmmoption=RUN_HMM_NGS
                    if (this%hmmoption==RUN_HMM_NULL) then
                        write(error_unit,*), "this%hmmoption not correctly specified"
                        stop
                    endif

                case("templatehaplotypes")
                    if (.not. allocated(second)) then
                        write(error_unit,*) "templatehaplotypes not set correctly"
                        stop
                    endif
                    read(second(1), *) this%nHapInSubH

                case("burninrounds")
                    read(second(1), *) this%HmmBurnInRound

                case("rounds")
                    read(second(1), *)this%nRoundsHMM

                case("parallelprocessors")
                    read(second(1), *) this%useProcs

                case("priorallelefrequencies")
                    if (.not. allocated(second)) then
                        write(*, "(A,A)") "WARNING: No prior allele frequencies file specified"
                    else
                        if (trim(second(1)) /= "None") then
                            inquire(file=trim(second(1)), exist=exists)
                            if (exists) then
                                this%PriorAllFreqs = .TRUE.
                                this%PriorAllFreqsFile = trim(second(1))
                                open(newunit=this%PriorAllFreqsUnit, file=trim(this%PriorAllFreqsFile), status="old")
                            else
                                write(0,*) "ERROR: File ", trim(second(1)), " does not exist"
                                stop 9
                            end if
                        endif
                    endif

                case("haplotypeslist")
                    if (.not. allocated(second)) then
                        write(*, "(A,A)") "WARNING: No list of haploytpes specified"
                    else
                        if (trim(second(1)) /= "None") then
                            inquire(file=trim(second(1)), exist=exists)
                            if (exists) then
                                this%HapList = .TRUE.
                                this%HapListFile = trim(second(1))
                                open(newunit=this%HapListUnit, file=trim(this%HapListFile), status="old")
                            else
                                write(0,*) "ERROR: File ", trim(second(1)), " does not exist"
                                stop 9
                            end if
                        endif
                    endif


                end select
            end if
            call OMP_set_num_threads(this%useProcs)
        end do READFILE

    end subroutine ReadInParameterFile

end module AlphaHmmInMod
