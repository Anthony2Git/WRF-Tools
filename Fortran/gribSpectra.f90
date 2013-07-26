! ============================================================================
! Name        : gribSpectra.f90
! Author      : Andre R. Erler
! Version     : 0.3
! Copyright   : GPL v3
! Description : Program to read spectral fields from grib files (ECMWF)
! ============================================================================

program gribSpectra

  ! imported modules
  use grib_api
  use netcdf

  implicit none

  ! declarations
  integer :: ifile, igrib, iret, ismis, varid, glen ! grib parameter
  integer :: ncid, ncerr, timeDimId, nDimId, lvlDimId, lmDimId  ! netcdf parameter
  integer :: phiId, lnspId, vorId, divId, Tid, timeId, nId, lvlId, lmId ! averaged variable IDs (netcdf)
  integer :: philmId, lnsplmId, vorlmId, divlmId, TlmId ! full coefficient variable IDs (netcdf)
  integer :: date, time, marsType ! meta data
  logical :: lana ! indicates whether dataset is analysis or forcast
  integer :: f, mssgcnt, k
  character :: shrtnm*5


  ! data declarations
  real(kind=8), dimension(:), allocatable :: phi, lnsp, philm, lnsplm
  real(kind=8), dimension(:,:), allocatable :: vor, div, T, vorlm, divlm, Tlm
  real(kind=8), dimension(:), allocatable :: vals ! all values in a grib message
  integer :: vork, divk, Tk ! level counter for 3D fields
  ! coordiante vectors (shperical harmonic coefficients, total wavenumber, vertical levels, time steps)
  integer, dimension(:), allocatable :: lmCoord, nCoord, lvlCoord, dates

  ! parameters
  logical :: ldiag, lcoef ! print diagnostics (or not)
  integer :: n, lvl, lm, nf
  integer, dimension(3) :: datepara
  real :: dos

  ! files and folders
  character (len = 182) :: infolder, outfolder
  character (len = 64) :: gribpfx, ncpfx
  character (len = 8) :: gribsfx, ncsfx
  character :: datename*2, filename*72
  character (len = 256) :: gribfile, ncfile

  ! namelist declarations
  character (len = 23), parameter :: namelistfile = 'namelist.grib'
  namelist /grid/ ldiag, lcoef, lana, n, lvl, datepara, dos
  namelist /input/ infolder, gribpfx, gribsfx
  namelist /output/ outfolder, ncpfx, ncsfx

! ===== read namelist input ==================================================

  ! read namelist input
  open(8, FILE=namelistfile, action='read',status='old', delim='quote')
  read(8, NML=grid)

  ! allocate arrays
  lm = n*(n+1)
  ! coodinates
  allocate(nCoord(n), lvlCoord(lvl))
  nCoord = (/ (f, f=0,n-1) /) ! wavenumbers
  lvlCoord = (/ (f, f=1,lvl) /) ! vertical levels
  lmCoord = (/ (f, f=0,lm-1) /) ! vertical levels
  ! data fields
  allocate(phi(n), lnsp(n), vor(lvl,n), div(lvl,n), T(lvl,n), vals(lm))

  ! files
  nf = (datepara(2)-datepara(1))/datepara(3)
  allocate(dates(nf))
  dates = (/ (f, f=datepara(1),datepara(2),datepara(3)) /)

  ! read file list
  read(8, NML=input)
  read(8, NML=output)
  close(8)

  ! Loop over filenames in filelist
#ifdef DEBUG
  FILELIST: do f = 1,1 ! execute only one cycle
#else
  FILELIST: do f = 1,nf
#endif

! ===== open grib file for reading ============================================

    write(datename,"(I2.2)") dates(f)
    filename = trim(gribpfx) // datename
    gribfile = trim(infolder) // trim(filename) // trim(gribsfx) ! full path + extension

    write(*,*)
    write(*,*) ' ===== time-step: ', trim(filename), ' ===== '
    write(*,*) ' Input Path: '
    write(*,*) trim(gribfile)
    write(*,*)

    ! open file
    call grib_open_file(ifile, gribfile, 'r')

    ! reset 3D level counter
    vork = 1; divk = 1; Tk = 1

! ===== open netcdf file for writing ==========================================

#ifdef DEBUG
    ncfile = 'test_output.nc' ! full path + extension
    write(*,*)
    write(*,*) ' ===== saving: ', trim(filename), ' ===== '
#else
    filename = trim(ncpfx) // datename
    ncfile = trim(outfolder) // trim(filename) // trim(ncsfx) ! full path + extension
#endif
    write(*,*) ' Output Path: '
    write(*,*) trim(ncfile)
    write(*,*)

    ! create new netcdf file
    ncerr = nf90_create(path=ncfile, cmode=NF90_NETCDF4, ncid=ncid) ! NF90_NETCDF4, NF90_CLOBBER

    ! define global attributes
    ncerr = nf90_put_att(ncid=ncid, varid=NF90_GLOBAL, name='sourcefile', values=trim(gribfile))
    ncerr = nf90_put_att(ncid=ncid, varid=NF90_GLOBAL, name='date', values=date)
    ncerr = nf90_put_att(ncid=ncid, varid=NF90_GLOBAL, name='time', values=time)
    if (lana) then
      ncerr = nf90_put_att(ncid=ncid, varid=NF90_GLOBAL, name='type', values='analysis')
    else
      ncerr = nf90_put_att(ncid=ncid, varid=NF90_GLOBAL, name='type', values='forecast')
    endif

    ! define dimensions and their attributes
    ! time (record dimension) and coordinate variable
    ncerr = nf90_def_dim(ncid=ncid, name='time', len=nf90_unlimited, dimid=timeDimId)
    ncerr = nf90_def_var(ncid=ncid, name='time', xtype=NF90_DOUBLE, dimids=(/ timeDimId /), varid=timeId)
    ncerr = nf90_put_att(ncid=ncid, varid=timeId, name='start', values='01/01/2010')
    ncerr = nf90_put_att(ncid=ncid, varid=timeId, name='units', values='days')
    ncerr = nf90_put_att(ncid=ncid, varid=timeId, name='long_name', values='Time since Jan. 1, 2010')
    ! total wavenumber and coordinate variable
    ncerr = nf90_def_dim(ncid=ncid, name='n', len=n, dimid=nDimId)
    ncerr = nf90_def_var(ncid=ncid, name='n', xtype=NF90_INT, dimids=(/ nDimId /), varid=nId)
    ncerr = nf90_put_att(ncid=ncid, varid=nId, name='units', values='')
    ncerr = nf90_put_att(ncid=ncid, varid=nId, name='long_name', values='Total Wavenumber')
    ! vertical level and coordinate variable
    ncerr = nf90_def_dim(ncid=ncid, name='level', len=lvl, dimid=lvlDimId)
    ncerr = nf90_def_var(ncid=ncid, name='level', xtype=NF90_INT, dimids=(/ lvlDimId /), varid=lvlId)
    ncerr = nf90_put_att(ncid=ncid, varid=lvlId, name='units', values='')
    ncerr = nf90_put_att(ncid=ncid, varid=lvlId, name='long_name', values='Hybrid Level No. from ToA')
    ! spherical coefficient and coordinate variable
    if (lcoef) then
      ncerr = nf90_def_dim(ncid=ncid, name='lm', len=lm, dimid=lmDimId)
      ncerr = nf90_def_var(ncid=ncid, name='lm', xtype=NF90_INT, dimids=(/ lmDimId /), varid=lmId)
      ncerr = nf90_put_att(ncid=ncid, varid=lmId, name='units', values='')
      ncerr = nf90_put_att(ncid=ncid, varid=lmId, name='long_name', values='Spherical Coefficients')
    endif
    ! define variables and their attributes
    ! Note: first dimension varies fastest
    ! phi, geopotential at surface (only in analysis)
    if (lana) then
      ncerr = nf90_def_var(ncid=ncid, name='phiN', xtype=NF90_DOUBLE, dimids=(/ nDimId /), varid=phiId)
      ncerr = nf90_put_att(ncid=ncid, varid=phiId, name='units', values='m^2/s^2')
      ncerr = nf90_put_att(ncid=ncid, varid=phiId, name='long_name', values='Geopotential')
    endif
    ! lnsp, log of surface pressure
    ncerr = nf90_def_var(ncid=ncid, name='lnspN', xtype=NF90_DOUBLE, dimids=(/ nDimId, timeDimId /), varid=lnspId)
    ncerr = nf90_put_att(ncid=ncid, varid=lnspId, name='units', values='hPa')
    ncerr = nf90_put_att(ncid=ncid, varid=lnspId, name='long_name', values='Logarithm of Sea-level Pressure')
    ! vor, rotational energy
    ncerr = nf90_def_var(ncid=ncid, name='En_rot', xtype=NF90_DOUBLE, dimids=(/ lvlDimId, nDimId, timeDimId /), varid=vorId)
    ncerr = nf90_put_att(ncid=ncid, varid=vorId, name='units', values='m^2/s^2')
    ncerr = nf90_put_att(ncid=ncid, varid=vorId, name='long_name', values='Rotational Kinetic Energy')
    ! div, divergent energy
    ncerr = nf90_def_var(ncid=ncid, name='En_div', xtype=NF90_DOUBLE, dimids=(/ lvlDimId, nDimId, timeDimId /), varid=divId)
    ncerr = nf90_put_att(ncid=ncid, varid=divId, name='units', values='m^2/s^2')
    ncerr = nf90_put_att(ncid=ncid, varid=divId, name='long_name', values='Divergent Kinetic Energy')
    ! T, temperature
    ncerr = nf90_def_var(ncid=ncid, name='Tn', xtype=NF90_DOUBLE, dimids=(/ lvlDimId, nDimId, timeDimId /), varid=Tid)
    ncerr = nf90_put_att(ncid=ncid, varid=Tid, name='units', values='K')
    ncerr = nf90_put_att(ncid=ncid, varid=Tid, name='long_name', values='Temperatur')
    ! Save full spherical coefficients in netcdf output
    CreateCoefs: if (lcoef) then
!      ! phi, geopotential at surface (only in analysis)
!      if (lana) then
!        ncerr = nf90_def_var(ncid=ncid, name='philm', xtype=NF90_DOUBLE, dimids=(/ lmDimId /), varid=philmId)
!        ncerr = nf90_put_att(ncid=ncid, varid=philmId, name='units', values='m^2/s^2')
!        ncerr = nf90_put_att(ncid=ncid, varid=philmId, name='long_name', values='Geopotential Coefficients')
!      endif
!      ! lnsp, log of surface pressure
!      ncerr = nf90_def_var(ncid=ncid, name='lnsplm', xtype=NF90_DOUBLE, dimids=(/ lmDimId, timeDimId /), varid=lnsplmId)
!      ncerr = nf90_put_att(ncid=ncid, varid=lnsplmId, name='units', values='hPa')
!      ncerr = nf90_put_att(ncid=ncid, varid=lnsplmId, name='long_name', values='Logarithm of Sea-level Pressure Coefficients')
      ! vor, rotational energy
      ncerr = nf90_def_var(ncid=ncid, name='Elm_rot', xtype=NF90_DOUBLE, dimids=(/ lvlDimId, lmDimId, timeDimId /), varid=vorlmId)
      ncerr = nf90_put_att(ncid=ncid, varid=vorlmId, name='units', values='m^2/s^2')
      ncerr = nf90_put_att(ncid=ncid, varid=vorlmId, name='long_name', values='Rotational Kinetic Energy Coefficients')
      ! div, divergent energy
      ncerr = nf90_def_var(ncid=ncid, name='Elm_div', xtype=NF90_DOUBLE, dimids=(/ lvlDimId, lmDimId, timeDimId /), varid=divlmId)
      ncerr = nf90_put_att(ncid=ncid, varid=divlmId, name='units', values='m^2/s^2')
      ncerr = nf90_put_att(ncid=ncid, varid=divlmId, name='long_name', values='Divergent Kinetic Energy Coefficients')
!      ! T, temperature
!      ncerr = nf90_def_var(ncid=ncid, name='Tlm', xtype=NF90_DOUBLE, dimids=(/ lvlDimId, lmDimId, timeDimId /), varid=TlmId)
!      ncerr = nf90_put_att(ncid=ncid, varid=TlmId, name='units', values='K')
!      ncerr = nf90_put_att(ncid=ncid, varid=TlmId, name='long_name', values='Temperatur Coefficients')
    endif CreateCoefs

    ! end definition section
    ncerr = nf90_enddef(ncid=ncid)

    ! write coordinate data
    ! time coordinate
    ncerr = nf90_put_var(ncid=ncid, varid=timeId, values=dos+dates(f))
    ! wavenumber coordinate
    ncerr = nf90_put_var(ncid=ncid, varid=nId, values=nCoord)
    ! vertical coordinate
    ncerr = nf90_put_var(ncid=ncid, varid=lvlId, values=lvlCoord)
    ! spherical coefficient coordinate
    if (lcoef) ncerr = nf90_put_var(ncid=ncid, varid=lmId, values=lmCoord)


! ===== read first message from grib file =====================================

    mssgcnt = 0 ! reset message counter for new file

    ! get message (get new message at end of while-loop)
    call grib_new_from_file(ifile, igrib, iret)

    ! loop over messages in grib file, until end of file is reached
#ifdef DEBUG
    ! only process first grib message
    MESSAGES: do while (mssgcnt<1) ! (k <= 1) ! k = 1
#else
    MESSAGES: do while (iret /= GRIB_END_OF_FILE)
#endif

      ! check for missing values
      ismis = 0
      call grib_is_missing(igrib,'values', ismis)

      MISSING: if (ismis == 1) then

        ! message is missing - skip processing
        mssgcnt = mssgcnt + 1
        write(*,*) ' ***** grib message', igrib, ' not found ***** '

      else MISSING ! if not (ismis == 1), i.e. if message is present

        ! message is present - start processing
        mssgcnt = mssgcnt + 1

        ! get global meta data
        global: if (mssgcnt == 1) then
          ! data and time
          call grib_get(igrib, 'dataDate', date)
          call grib_get(igrib, 'dataTime', time)
          ! type of dataset
          call grib_get(igrib, 'marsType', marsType)
          ana: if (lana.and.(marsType.ne.2)) then ! analysis = 2
            write(*,*) ' *** Warning: this is not an Analysis ***'
          elseif ((.not.lana).and.(marsType.ne.9)) then ! forcast = 9
            write(*,*) ' *** Warning: this is not a Forecast ***'
          endif ana
        endif global

        ! get variable meta data
        call grib_get(igrib, 'shortName', shrtnm)
        call grib_get(igrib, 'paramId', varid)
        call grib_get(igrib, 'level', k)
        call grib_get_size(igrib, 'values', glen)

        ! load actual values
        call grib_get(igrib, 'values', vals)

! ===== diagnostic output ===============================================

#ifdef DEBUG
        ! print all diagnostics
        diagnostic: if (ldiag) then
#else
        ! print some diagnostics for one level (last preferred)
        diagnostic: if ((varid==129).or.(varid==152).or.((k==lvl).and. &
                    ((varid==138).or.(varid==155).or.(varid==130)))) then
#endif
          ! General
          write(*,*)
          write(*,*) ' ===== found grib message', mssgcnt, ' ===== '

          write(*,*) '    variable name: ', shrtnm, ' (#', varid, ')'
          write(*,*) '    hybrid level: ', k
          write(*,*) '    number of values:', glen
#ifdef DEBUG
          ! variable specific diagnostics
          vorticity: if (varid == 138) then
            write(*,*) 'Min / Max values for Erot(n):', minval(vor(k,:)), '/', maxval(vor(k,:))
            write(*,*) 'Mean value of Erot(n):', sum(vor(k,:))/real(n)
            write(*,*) 'Global mean value of Urot:', sqrt(vor(k,1)), '(n=0,m=0)'
          endif vorticity
          temperature: if (varid == 130) then
            write(*,*) 'Min / Max values for T^2(n):', minval(T(k,:)), '/', maxval(T(k,:))
            write(*,*) 'Mean value of T^2(n):', sum(T(k,:))/real(n)
            write(*,*) 'Global mean value of T:', sqrt(T(k,1)), '(n=0,m=0)'
          endif temperature
#endif
        endif diagnostic

!        ! print some more diagnostics
!        write(*,*) 'Min / Max values:', minval(vals), '/', maxval(vals)
!        write(*,*) 'Mean value:', sum(vals)/real(glen)


! ===== compute power spectrum ===============================================
! note that the power spectrum is computed level-wise within a loop

        Compute: if (lm == glen) then ! check length
          variable: select case (varid)
            case (129) ! geopotential height at surface (orography), 2D
              call powerspectrum(vals, phi(:), n, .false.)
              ncerr = nf90_put_var(ncid=ncid, varid=phiId, values=phi) ! save to file
!              if (lcoef) ncerr = nf90_put_var(ncid=ncid, varid=philmId, values=vals)
              write(*,*) 'Saving variable phiN (Surface Geopotential) to netcdf file.'
            case (152) ! logarithm of surface pressure, 2D
              call powerspectrum(vals, lnsp(:), n, .false.)
              ncerr = nf90_put_var(ncid=ncid, varid=lnspId, values=lnsp) ! save to file
!              if (lcoef) ncerr = nf90_put_var(ncid=ncid, varid=lnspId, values=vals)
              write(*,*) 'Saving variable lnspN (Logarithm of Surface Pressure) to netcdf file.'
            case (138) ! vorticity, 3D
              call powerspectrum(vals, vor(k,:), n, .true.)
              if (lcoef.and.(vork.eq.0)) allocate(vorlm(lvl,lm))
              if (lcoef) vorlm(k,:) = vals
              vork = vork + 1
              saveVor: if (vork .eq. lvl) then
                ncerr = nf90_put_var(ncid=ncid, varid=vorId, values=vor) ! save to file
                write(*,*) 'Saving variable En_rot (Rotational Kinetic Energy) to netcdf file.'
                if (lcoef) ncerr = nf90_put_var(ncid=ncid, varid=vorlmId, values=vorlm) ! save to file
                if (lcoef) deallocate(vorlm)
              endif saveVor
            case (155) ! divergence, 3D
              call powerspectrum(vals, div(k,:), n, .true.)
              if (lcoef.and.(divk.eq.0)) allocate(divlm(lvl,lm))
              if (lcoef) divlm(k,:) = vals
              divk = divk + 1
              saveDiv: if (divk .eq. lvl) then
                ncerr = nf90_put_var(ncid=ncid, varid=divId, values=div) ! save to file
                write(*,*) 'Saving variable En_div (Divergent Kinetic Energy) to netcdf file.'
                if (lcoef) ncerr = nf90_put_var(ncid=ncid, varid=divlmId, values=divlm) ! save to file
                if (lcoef) deallocate(divlm)
              endif saveDiv
            case (130) ! Temperature, 3D
              call powerspectrum(vals, T(k,:), n, .false.)
!              if (lcoef.and.(Tk.eq.0)) allocate(Tlm(lvl,lm))
!              if (lcoef) Tlm(k,:) = vals
              Tk = Tk + 1
              saveT: if (Tk .eq. lvl) then
                ncerr = nf90_put_var(ncid=ncid, varid=Tid, values=T) ! save to file
                write(*,*) 'Saving variable Tn (Temperature) to netcdf file.'
!                if (lcoef) ncerr = nf90_put_var(ncid=ncid, varid=TlmId, values=Tlm) ! save to file
!                if (lcoef) deallocate(Tlm)
              endif saveT
          end select variable ! varid
        else Compute
          write(*,*) ' ** *** ** WARNING! ** *** **'
          write(*,*) ' * Length of field ', shrtnm, 'is incompatible with n =', n, '*'
        endif Compute

      ! finish computation
      endif MISSING

      ! release processed message
      call grib_release(igrib)

      ! get new message for next iteration
      call grib_new_from_file(ifile, igrib, iret)

    enddo MESSAGES ! loop over messages

    ! close netcdf file
    ncerr = nf90_close(ncid=ncid)

    write(*,*)
    write(*,*) ' ===== done with ', trim(filename), ' ===== '
    write(*,*)

  enddo FILELIST ! loop over filelist

end program gribSpectra

! ===== actual computation of power spectrum =================================
! procedure adapted from Nils Wedi (ECMWF, 2011, pers. com.)) and Lambert (AO 1984)

pure subroutine powerspectrum(vals, spc, n, lenergy)

  ! declarations: external variables
  logical, intent(in) :: lenergy
  integer, intent(in) :: n
  real(kind=8), dimension(n*(n+1)), intent(in) :: vals
  real(kind=8), dimension(n), intent(out) :: spc
  ! declarations: internal variables
  integer :: i, j, up, lo
  real(kind=8) :: r2
  ! variable initializaion
  parameter ( r2 = 6371229.**2 ) ! Earth's radius (squared)

  ! sum over coefficients (vectorized form)
  ! initialization; special treatment for zonal means (M = 0)
  up = 2*n
  spc = 0.5*(vals(1:up-1:2)**2 + vals(2:up:2)**2) ! j = 1, i.e. M = 0
  ! loop over M-values (zonal wave number)
  M: do j = 2, n ! loop over M; special treatment of M=0 above (i.e. j=1)
      ! loop over N-values (total wave number)
      lo = up ! lo = 2*(j-1)*n - (j-1)*(j-2)
      up = lo + 2*(n-j+1) ! lo(j+1) = up(j)
      spc(j:n) = spc(j:n) + (vals(lo+1:up-1:2)**2 + vals(lo+2:up:2)**2)
  enddo M ! loop over M

  ! normalize spectral power
  ! cfg. Lambert (1984), IFS coef's already include a factor of 2
  ! Note: N = 0 (i.e. i = 1) is already normalized to the global mean
  NORM: if (lenergy) then
    ! assume input is vorticity or divergence and convert to velocity
    forall (i=2:n) spc(i) = spc(i) * r2/(i*(i-1))
  endif NORM ! if lenergy

end subroutine powerspectrum

! sum over coefficients without vectorization
!
!  integer :: cnt
!
!  ! sum over coefficients (vectorized form)
!  ! special treatment for zonal means (M = 0)
!  cnt = 0 ! linear index for for vals array
!  MZERO: do i = 1, n ! loop over N-values (total wave number)
!      cnt = cnt + 2 ! real part (cnt-1) and imaginary part (cnt)
!      spc(i) = vals(cnt-1)**2 + vals(cnt)**2 ! add M=0-coefficient to N-bin
!  enddo MZERO ! loop over N
!  ! loop over M-values (zonal wave number)
!  ZONAL: do j = 2, n ! loop over M; special treatment of M=0 above (i.e. j=1)
!      ! loop over N-values (total wave number)
!      TOTAL: do i = j, n
!          ! add M-coefficient to N-bin
!          cnt = cnt + 2 ! real part (cnt-1) and imaginary part (cnt)
!          spc(i) = spc(i) + 0.5*(vals(cnt-1)**2 + vals(cnt)**2)
!      enddo TOTAL ! loop over N
!  enddo ZONAL ! loop over M
!
!  ! normalize spectral power
!  ! cfg. Lambert (1984), IFS coef's already include a factor of 2
!  ! Note: N = 0 (i.e. i = 1) is already normalized to the global mean
!  NORM: if (lenergy) then
!    ! assume input is vorticity or divergence and convert to velocity
!    NormEnergy: do i = 2, n
!      spc(i) = spc(i) * r2/(i*(i-1))
!    enddo NormEnergy
!  else NORM
!    ! assume input is in standard spherical harmonics
!    NormOther: do i = 2, n
!      spc(i) = spc(i) * (i*(i-1))/r2
!    enddo NormOther
!  endif NORM ! if lenergy

! some code to allocate grib values dynamically
!
!  integer :: glen, oldglen = 0 ! data parameter, 'oldglen' checks for reallocating
!
!        ! allocate data array if necessary
!        call grib_get_size(igrib, 'values', glen)
!        if (oldglen /= glen) then
!          if (oldglen == 0) then
!            ! allocate if not yet done
!            allocate(vals(glen))
!          else
!            ! reallocate, if resizing necessary
!            deallocate(vals)
!            allocate(vals(glen))
!          endif
!          ! remember last array size for next iteration
!          oldglen = glen
!        endif
