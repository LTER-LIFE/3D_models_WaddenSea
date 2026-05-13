#include "cppdefs.h"
!-----------------------------------------------------------------------
!BOP
!
! !ROUTINE: Read variables from a GETM NetCDF hotstart file
!
! !INTERFACE:
   subroutine read_restart_ncdf(runtype,loop,julianday,secondsofday,tstep)
!
! !DESCRIPTION:
!  Reads from a NetCDF files (with handler ncid) opened with
!  open\_restart\_ncdf(). All variable id's are initialised. The variables
!  can be read from hotstart files with the same dimensions as given by
!  imin:imax,jmin:jmax - or - from a hotstart file with the same dimensions
!  as topo.nc (and on the same grid). This allows to use 'ncmerge' to
!  combine a number of hotstart files in to one - make a new sub-domain
!  decomposition and use the newly created hotstart file. It might be
!  necessary to use 'ncks' to cut the file to be have the same dimensions
!  as topo.nc. Allowing for the file naming scheme in GETM links for each
!  sub-domain should be made - e.g. ln -s restart.in restart.000.in; ln -s
!  restart.in restart.001.in etc.\newline
!  Halo-zones are updated using calls to update\_2d\_halo() and
!  update\_3d\_halo().
!
! !USES:
   use netcdf
   use ncdf_restart
   use domain, only: iextr,jextr,ioff,joff
   use domain, only: az,au,av
   use halo_zones, only: update_2d_halo,update_3d_halo,wait_halo
   use halo_zones, only: H_TAG,U_TAG,V_TAG
   use variables_2d
   use exceptions, only: getm_error
#ifndef NO_3D
   use variables_3d
   use variables_waves
#ifdef GETM_BIO
   use bio, only: bio_calc
   use bio_var, only: numc
   use getm_bio, only: bio_init_method
#ifdef BFM_GOTM
   use variables_bio_3d, only: cc3d 
#endif
#endif
#ifdef _FABM_
   use getm_fabm, only: fabm_init_method
   use getm_fabm, only: fabm_pel,fabm_ben
#endif
#endif
#ifdef SPM
   use suspended_matter
#endif
   IMPLICIT NONE
!
! !INPUT PARAMETERS:
   integer, intent(in)      :: runtype
!
! !OUTPUT PARAMETERS:
   integer, intent(out)      :: loop,julianday,secondsofday
   REALTYPE, intent(out)     :: tstep
!
! !DEFINED PARAMTERS:
!
! !LOCAL VARIABLES:
   integer         :: ioff_l,joff_l,ioff_0,joff_0
   integer         :: ioff_0_from_file,joff_0_from_file
   integer         :: ifill_from,jfill_from
   integer         :: iread_from,jread_from
!
! !REVISION HISTORY:
!  Original author(s): Karsten Bolding
!
! !LOCAL VARIABLES:
#ifdef BFM_GOTM
   integer         :: il,ih,i,istart,istop
   integer         :: jl,jh,j,jstart,jstop
#else
   integer         :: il,ih,iloc,ilen,i,istart,istop
   integer         :: jl,jh,jloc,jlen,j,jstart,jstop
#endif
   integer         :: n
!EOP
!-----------------------------------------------------------------------
!BOC
   STDERR "read_restart_ncdf_0", &
                           loop_id,julianday_id,secondsofday_id,timestep_id

   status = nf90_get_var(ncid,loop_id,loop)
   if (status .NE. NF90_NOERR) go to 10

   status = nf90_get_var(ncid,julianday_id,julianday)
   if (status .NE. NF90_NOERR) go to 10

   status = nf90_get_var(ncid,secondsofday_id,secondsofday)
   if (status .NE. NF90_NOERR) go to 10

   status = nf90_get_var(ncid,timestep_id,tstep)
   if (status .NE. NF90_NOERR) go to 10

   ioff_0_from_file=-9999
   status = nf90_inquire_attribute(ncid,NF90_GLOBAL,'joff', &
                                             xtype= joff_0_from_file)
   !new way: ioff and joff are the smallest values  of all the
   ! ioffs in the collection subdomain files.
   if (status.eq.NF90_NOERR) then
     status = nf90_get_att(ncid,NF90_GLOBAL,'ioff',ioff_0_from_file)
     if (status .NE. NF90_NOERR) go to 10

     status = nf90_get_att(ncid,NF90_GLOBAL,'joff',joff_0_from_file)
     if (status .NE. NF90_NOERR) go to 10
   else
     !old way: ioff_0 and joff_0 are the values  of the first subdomain,
     ! assuming that this subdomain is is in the colomn of the most left
     ! subdomains and in the row of the lowest (southern) subdomains.
     ioff_0_from_file=-9999
     status = nf90_inquire_attribute(ncid,NF90_GLOBAL, &
                                         'ioff_0',xtype= joff_0_from_file)
     if (status.eq.NF90_NOERR) then
       status = nf90_get_att(ncid,NF90_GLOBAL,'ioff_0',ioff_0_from_file)
       if (status .NE. NF90_NOERR) go to 10

       status = nf90_get_att(ncid,NF90_GLOBAL,'joff_0',joff_0_from_file)
       if (status .NE. NF90_NOERR) go to 10
     endif
   endif


   STDERR "read_restart_ncdf_1"

!  allows reading from subdomain or topo.nc sized files
!  i.e. ncmerged files cut to the same size as topo.nc
#ifdef __READ_HOT_HALOS_
   if (xlen .eq. ((imax+HALO)-(imin-HALO)+1) .and.  &
       ylen .eq. ((jmax+HALO)-(jmin-HALO)+1) ) then
      LEVEL3 'hotstart file(s) include HALO-zones'
      il = 1 ; ih = xlen - 2*HALO
      jl = 1 ; jh = ylen - 2*HALO
      start(1) = il + HALO
      start(2) = jl + HALO
#else
   if (xlen .eq. (imax-imin+1) .and. ylen .eq. (jmax-jmin+1) ) then
      LEVEL3 'hotstart file(s) do NOT include HALO-zones'
      il = 1 ; ih = xlen
      jl = 1 ; jh = ylen
      start(1) = il
      start(2) = jl
#endif
      iloc = 1 ; jloc = 1
      ilen = ih-il+1
      jlen = jh-jl+1
      STDERR "read_restart_ncdf: subdomain file"
   else
      ioff_0=(ioff-imax*(ioff/imax))
      joff_0=(joff-jmax*(joff/jmax))
      LEVEL1 "joff/jmax",joff/jmax
      ioff_l=ioff-ioff_0
      joff_l=joff-joff_0
      LEVEL1 "jmax,joff,joff_0,joff_l",jmax,joff,joff_0,joff_l      
!possibility to use "old" netcdf restart files...
      if (ioff_0_from_file .eq.-9999) then
         ioff_0=0;joff_0=0
         joff_l=jmax*(joff/jmax+1)
         if (joff.le.0) then
            joff_l=0
         endif
         LEVEL1 "joff_l",joff_l
      else
!       [ij]off_0 : relative difference of position the sw-corner of the
!                          subdomain in the sw corner of the domain.
        ioff_0=ioff_0-ioff_0_from_file
        joff_0=joff_0-joff_0_from_file
      endif
!     ioff_0 < 0: filling of subdomain start at -ioff_0 ,
!                       but reading of data start from position 1
!     ioff_0 > 0: filling of subdomain start at       0 ,
!                       but reading of data start from position ioff_0
      if ( ioff_0 <= 0 ) then
         ifill_from=-ioff_0;iread_from=0
      else
         ifill_from=0; iread_from=ioff_0
      endif
      if ( joff_0 <= 0 ) then
         jfill_from=-joff_0;jread_from=0
      else
         jfill_from=0; jread_from=joff_0
      endif

! iloc: first index of array where the readed data shall be stored
! ilen: last  index of array where the readed data shall be stored
      iloc = imin;if (ioff_l.eq.0) iloc = imin+ifill_from
      jloc = jmin;if (joff_l.eq.0) jloc = jmin+jfill_from
! il:ih  array range of data  which are red from array in netcdf file
LEVEL1 "imin,ioff_l,iread_from,il,ifill_from",imin,ioff_l,iread_from,il,ifill_from
LEVEL1 "jmin,joff_l,jread_from,jl,jfill_from",jmin,joff_l,jread_from,jl,jfill_from
      il = max(imin+ioff_l+iread_from,1)
LEVEL1 "il",il
      if ( ioff_l > 0 ) il=il-ifill_from
LEVEL1 "il",il
      jl = max(jmin+joff_l+jread_from,1)
LEVEL1 "jl",jl
      if ( joff_l > 0 ) jl=jl-jfill_from
LEVEL1 "jl",jl
      ih = min(il+imax-iloc,xlen)
      jh = min(jl+jmax-jloc,ylen)
      ilen = ih-il+iloc
      jlen = jh-jl+jloc

      STDERR "read_restart_ncdf: fulldomain file"
      STDERR "read_restart_ncdf ioff_0_ff,joff_0_ff",ioff_0_from_file,joff_0_from_file
      STDERR "read_restart_ncdf ioff,joff",ioff,joff
      STDERR "read_restart_ncdf ioff_0,joff_0",ioff_0,joff_0
      STDERR "read_restart_ncdf ioff_l,joff_l",ioff_l,joff_l
      STDERR "read_restart_ncdf il,ih",il,ih
      STDERR "read_restart_ncdf jl,jh",jl,jh
      STDERR "read_restart_ncdf iloc,jloc",iloc,jloc
      STDERR "read_restart_ncdf ilen,jlen",ilen,jlen
      STDERR "read_restart_ncdf iread_from,jread_from",iread_from,jread_from
      STDERR "read_restart_ncdf ifill_from,jfill_from",ifill_from,jfill_from
!stop
   end if
   start(1) = il ; edges(1) = ih-il+1
   start(2) = jl ; edges(2) = jh-jl+1
#ifndef NO_3D
   start(3) = 1  ; edges(3) = kmax+1
#endif

      STDERR "read_restart_ncdf edges",edges
      STDERR "read_restart_ncdf start",start
!  z is required
   status = &
   nf90_get_var(ncid,z_id,z(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   LEVEL4 ' mpi-read returned with status=',status
   if (status .NE. NF90_NOERR) go to 10
   call update_2d_halo(z,z,az,imin,jmin,imax,jmax,H_TAG)
   call wait_halo(H_TAG)

   status = &
   nf90_get_var(ncid,zo_id,zo(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   if (status .NE. NF90_NOERR) then
      LEVEL3 "read_restart_ncdf(): setting zo=z"
      zo=z
   else
      call update_2d_halo(zo,zo,az,imin,jmin,imax,jmax,H_TAG)
      call wait_halo(H_TAG)
   end if

   status = &
   nf90_get_var(ncid,U_id,U(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   if (status .NE. NF90_NOERR) then
      LEVEL3 "read_restart_ncdf(): setting U=0"
      U=_ZERO_
   else
      call update_2d_halo(U,U,au,imin,jmin,imax,jmax,U_TAG)
      call wait_halo(U_TAG)
   end if

   status = &
   nf90_get_var(ncid,SlUx_id,SlUx(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   if (status .NE. NF90_NOERR) then
      LEVEL3 "read_restart_ncdf(): setting SlUx=0"
      SlUx=_ZERO_
   else
      call update_2d_halo(SlUx,SlUx,au,imin,jmin,imax,jmax,U_TAG)
      call wait_halo(U_TAG)
   end if

   status = &
   nf90_get_var(ncid,Slru_id,Slru(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   if (status .NE. NF90_NOERR) then
      LEVEL3 "read_restart_ncdf(): setting Slru=0"
   else
      call update_2d_halo(Slru,Slru,au,imin,jmin,imax,jmax,U_TAG)
      call wait_halo(U_TAG)
   end if

   status = &
   nf90_get_var(ncid,V_id,V(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   if (status .NE. NF90_NOERR) then
      LEVEL3 "read_restart_ncdf(): setting V=0"
      V=_ZERO_
   else
      call update_2d_halo(V,V,av,imin,jmin,imax,jmax,V_TAG)
      call wait_halo(V_TAG)
   end if

   status = &
   nf90_get_var(ncid,SlVx_id,SlVx(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   if (status .NE. NF90_NOERR) then
      LEVEL3 "read_restart_ncdf(): setting SlVx=0"
      SlVx=_ZERO_
   else
      call update_2d_halo(SlVx,SlVx,av,imin,jmin,imax,jmax,V_TAG)
      call wait_halo(V_TAG)
   end if

   status = &
   nf90_get_var(ncid,Slrv_id,Slrv(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
   if (status .NE. NF90_NOERR) then
      LEVEL3 "read_restart_ncdf(): setting Slrv=0"
      Slrv=_ZERO_
   else
      call update_2d_halo(Slrv,Slrv,av,imin,jmin,imax,jmax,V_TAG)
      call wait_halo(V_TAG)
   end if

#ifndef NO_3D
   if (runtype .ge. 2)  then
      status = &
      nf90_get_var(ncid,ssen_id,ssen(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting ssen=0"
         ssen=_ZERO_
      else
         call update_2d_halo(ssen,ssen,az,imin,jmin,imax,jmax,H_TAG)
         call wait_halo(H_TAG)
      end if

      status = &
      nf90_get_var(ncid,ssun_id,ssun(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting ssun=0"
         ssun=_ZERO_
!         where (au .eq. 0)  !JM tried this to read old restart files, helped but more problems
!            ssun=10.2
!         end where
      else
         call update_2d_halo(ssun,ssun,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      end if

      status = &
      nf90_get_var(ncid,ssvn_id,ssvn(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting ssvn=0"
         ssvn=_ZERO_
!         where (av .eq. 0)  !JM tried this to read old restart files, helped but more problems
!            ssvn=10.2
!         end where
      else
         call update_2d_halo(ssvn,ssvn,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      end if

      status = &
      nf90_get_var(ncid,sseo_id,sseo(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting sseo=0"
         sseo=_ZERO_
      else
         call update_2d_halo(sseo,sseo,az,imin,jmin,imax,jmax,H_TAG)
         call wait_halo(H_TAG)
      end if

      status = &
      nf90_get_var(ncid,ssuo_id,ssuo(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting ssuo=0"
         ssuo=_ZERO_
      else
         call update_2d_halo(ssuo,ssuo,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      end if

      status = &
      nf90_get_var(ncid,ssvo_id,ssvo(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting ssvo=0"
         ssvo=_ZERO_
      else
         call update_2d_halo(ssvo,ssvo,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      end if

      if (Uint_id .ne. -1) then
         status = &
         nf90_get_var(ncid,Uint_id,Uint(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(Uint,Uint,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      else
         LEVEL3 "read_restart_ncdf(): setting Uint=0"
         LEVEL3 "                     (invalid within 2d cycle!)"
         Uint=_ZERO_
      end if

      if (Vint_id .ne. -1) then
         status = &
         nf90_get_var(ncid,Vint_id,Vint(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(Vint,Vint,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      else
         LEVEL3 "read_restart_ncdf(): setting Vint=0"
         LEVEL3 "                     (invalid within 2d cycle!)"
         Vint=_ZERO_
      end if

      if (Uadv_id .ne. -1) then
         status = &
         nf90_get_var(ncid,Uadv_id,Uadv(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(Uadv,Uadv,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      else if (Uinto_id .ne. -1) then
         status = &
         nf90_get_var(ncid,Uinto_id,Uadv(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(Uadv,Uadv,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      else
         LEVEL3 "read_restart_ncdf(): setting Uadv=0"
         Uadv=_ZERO_
      end if

      if (Vadv_id .ne. -1) then
         status = &
         nf90_get_var(ncid,Vadv_id,Vadv(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(Vadv,Vadv,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      else if (Vinto_id .ne. -1) then
         status = &
         nf90_get_var(ncid,Vinto_id,Vadv(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(Vadv,Vadv,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      else
         LEVEL3 "read_restart_ncdf(): setting Vadv=0"
         Vadv=_ZERO_
      end if

      if (UEulerInt_id .ne. -1) then
         status = &
         nf90_get_var(ncid,UEulerInt_id,UEulerInt(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(UEulerInt,UEulerInt,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving UEulerInt=0"
      end if

      if (VEulerInt_id .ne. -1) then
         status = &
         nf90_get_var(ncid,VEulerInt_id,VEulerInt(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(VEulerInt,VEulerInt,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving VEulerInt=0"
      end if

      if (UEulerAdv_id .ne. -1) then
         status = &
         nf90_get_var(ncid,UEulerAdv_id,UEulerAdv(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(UEulerAdv,UEulerAdv,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving UEulerAdv=0"
      end if

      if (VEulerAdv_id .ne. -1) then
         status = &
         nf90_get_var(ncid,VEulerAdv_id,VEulerAdv(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(VEulerAdv,VEulerAdv,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving VEulerAdv=0"
      end if

      if (UStokesCint_id .ne. -1) then
         status = &
         nf90_get_var(ncid,UStokesCint_id,UStokesCint(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(UStokesCint,UStokesCint,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving UStokesCint=0"
      end if

      if (VStokesCint_id .ne. -1) then
         status = &
         nf90_get_var(ncid,VStokesCint_id,VStokesCint(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(VStokesCint,VStokesCint,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving VStokesCint=0"
      end if

      if (UStokesCadv_id .ne. -1) then
         status = &
         nf90_get_var(ncid,UStokesCadv_id,UStokesCadv(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(UStokesCadv,UStokesCadv,au,imin,jmin,imax,jmax,U_TAG)
         call wait_halo(U_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving UStokesCadv=0"
      end if

      if (VStokesCadv_id .ne. -1) then
         status = &
         nf90_get_var(ncid,VStokesCadv_id,VStokesCadv(iloc:ilen,jloc:jlen),start(1:2),edges(1:2))
         if (status .NE. NF90_NOERR) go to 10
         call update_2d_halo(VStokesCadv,VStokesCadv,av,imin,jmin,imax,jmax,V_TAG)
         call wait_halo(V_TAG)
      else
         LEVEL3 "read_restart_ncdf(): leaving VStokesCadv=0"
      end if

      status = &
      nf90_get_var(ncid,uu_id,uu(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting uu=0"
         uu=_ZERO_
      else
         call update_3d_halo(uu,uu,au,imin,jmin,imax,jmax,kmax,U_TAG)
         call wait_halo(U_TAG)
      end if

      status = &
      nf90_get_var(ncid,vv_id,vv(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting vv=0"
         vv=_ZERO_
      else
         call update_3d_halo(vv,vv,av,imin,jmin,imax,jmax,kmax,V_TAG)
         call wait_halo(V_TAG)
      end if

      status = &
      nf90_get_var(ncid,ww_id,ww(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting ww=0"
         ww=_ZERO_
      else
         call update_3d_halo(ww,ww,az,imin,jmin,imax,jmax,kmax,H_TAG)
         call wait_halo(H_TAG)
      end if

      status = &
      nf90_get_var(ncid,uuEx_id,uuEx(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting uuEx=0"
         uuEx=_ZERO_
      else
         call update_3d_halo(uuEx,uuEx,au,imin,jmin,imax,jmax,kmax,U_TAG)
         call wait_halo(U_TAG)
      end if

      status = &
      nf90_get_var(ncid,vvEx_id,vvEx(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) then
         LEVEL3 "read_restart_ncdf(): setting vvEx=0"
         vvEx=_ZERO_
      else
         call update_3d_halo(vvEx,vvEx,av,imin,jmin,imax,jmax,kmax,V_TAG)
         call wait_halo(V_TAG)
      end if

!     tke is required
      status = &
      nf90_get_var(ncid,tke_id,tke(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) go to 10
      call update_3d_halo(tke,tke,az,imin,jmin,imax,jmax,kmax,H_TAG)
      call wait_halo(H_TAG)

!     eps is required
      status = &
      nf90_get_var(ncid,eps_id,eps(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) go to 10
      call update_3d_halo(eps,eps,az,imin,jmin,imax,jmax,kmax,H_TAG)
      call wait_halo(H_TAG)

!     num is required
      status = &
      nf90_get_var(ncid,num_id,num(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) go to 10
      call update_3d_halo(num,num,az,imin,jmin,imax,jmax,kmax,H_TAG)
      call wait_halo(H_TAG)

!     nuh is required
      status = &
      nf90_get_var(ncid,nuh_id,nuh(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
      if (status .NE. NF90_NOERR) go to 10
      call update_3d_halo(nuh,nuh,az,imin,jmin,imax,jmax,kmax,H_TAG)
      call wait_halo(H_TAG)

      if (ho_id .ne. -1) then
         status = &
         nf90_get_var(ncid,ho_id,ho(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_3d_halo(ho,ho,az,imin,jmin,imax,jmax,kmax,H_TAG)
         call wait_halo(H_TAG)
      endif

      if (hn_id .ne. -1) then
         status = &
         nf90_get_var(ncid,hn_id,hn(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_3d_halo(hn,hn,az,imin,jmin,imax,jmax,kmax,H_TAG)
         call wait_halo(H_TAG)
      endif

#ifndef NO_BAROCLINIC
      if (runtype .ge. 3)  then
!        T is required
         status = &
         nf90_get_var(ncid,T_id,T(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_3d_halo(T,T,az,imin,jmin,imax,jmax,kmax,H_TAG)
         call wait_halo(H_TAG)

!        S is required
         status = &
         nf90_get_var(ncid,S_id,S(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         call update_3d_halo(S,S,az,imin,jmin,imax,jmax,kmax,H_TAG)
         call wait_halo(H_TAG)
      end if
#endif

      if (nonhyd_method .ne. 0) then
         if (nonhyd_method .eq. 1) then
            if (minus_bnh_id .eq. -1) then
               LEVEL3 "read_restart_ncdf(): setting minus_bnh=0"
               minus_bnh = _ZERO_
            else
               status = &
               nf90_get_var(ncid,minus_bnh_id,minus_bnh(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
               if (status .NE. NF90_NOERR) go to 10
               call update_3d_halo(minus_bnh,minus_bnh,az,imin,jmin,imax,jmax,kmax,H_TAG)
               call wait_halo(H_TAG)
            end if
         end if

         if (wco_id .eq. -1) then
            LEVEL3 "read_restart_ncdf(): setting wco=0"
            wco = _ZERO_
         else
            status = &
            nf90_get_var(ncid,wco_id,wco(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
            if (status .NE. NF90_NOERR) go to 10
            call update_3d_halo(wco,wco,az,imin,jmin,imax,jmax,kmax,H_TAG)
            call wait_halo(H_TAG)
         end if
      end if

#ifdef SPM
      if(spm_calc) then
        if (spm_hotstart) then
         status = &
         nf90_get_var(ncid,spm_id,spm(iloc:ilen,jloc:jlen,0:kmax),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) then
            LEVEL3 "read_restart_ncdf(): setting spm=0"
            spm=_ZERO_
         else
            call update_3d_halo(spm,spm,az,imin,jmin,imax,jmax,kmax,H_TAG)
            call wait_halo(H_TAG)
         end if

         status = &
         nf90_get_var(ncid,spmpool_id,spm_pool(iloc:ilen,jloc:jlen),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) then
            LEVEL3 "read_restart_ncdf(): setting spmpool=0"
            spm_pool=_ZERO_
         else
            call update_2d_halo(spm_pool,spm_pool,az,imin,jmin,imax,jmax,H_TAG)
            call wait_halo(H_TAG)
         end if
        else
         LEVEL3 'spm variables not read from hotstart file'
         LEVEL3 'set spm_init_method=0 to read them from hotstart file'
        end if
      end if
#endif
#ifdef _FABM_
      if(allocated(fabm_pel) .and. fabm_init_method .eq. 0) then
         start(4) = 1;  edges(4) = size(fabm_pel,4)
         status = &
         nf90_get_var(ncid,fabm_pel_id,fabm_pel(iloc:ilen,jloc:jlen,0:kmax,:),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
         do n=lbound(fabm_pel,4),ubound(fabm_pel,4)
            call update_3d_halo(fabm_pel(:,:,:,n),fabm_pel(:,:,:,n),   &
                                az,imin,jmin,imax,jmax,kmax,H_TAG)
            call wait_halo(H_TAG)
         end do

         if (fabm_ben_id .gt. 0) then
            start(3) = 1;  edges(3) = size(fabm_ben,3)
            status = &
            nf90_get_var(ncid,fabm_ben_id,fabm_ben(iloc:ilen,jloc:jlen,:),start(1:3),edges(1:3))
            if (status .NE. NF90_NOERR) go to 10
            do n=lbound(fabm_ben,3),ubound(fabm_ben,3)
               call update_2d_halo(fabm_ben(:,:,n),fabm_ben(:,:,n),    &
                                   az,imin,jmin,imax,jmax,H_TAG)
               call wait_halo(H_TAG)
            end do
         end if
      end if
#endif
#ifdef GETM_BIO
      if(bio_calc .and. bio_init_method .eq. 0) then

!AN         start(1) = 1;  edges(1) = numc
!AN         LEVEL3 'DEBUG edges(1) = numc = ',numc
#ifdef _READ_HOT_HALOS_
STDERR 'needs a fix here - read_restart_ncdf()'
call getm_error('read_restart_ncdf()','needs a fix here HOT-HALO plus BIO problem')
stop
         start(2) = il; edges(2) = numc
         start(3) = jl; edges(3) = numc
#else
!AN         LEVEL3 'DEBUG edges(2) and edges(3)',edges(2),edges(3)
!AN         start(2) = il; edges(2) = ih-il+1
!AN         start(3) = jl; edges(3) = jh-jl+1
!AN         LEVEL3 'DEBUG edges(2) and edges(3)',edges(2),edges(3)
#endif
#ifndef BFM_GOTM
         start(4) = 1;  edges(4) = kmax+1

         status = &
         nf90_get_var(ncid,bio_id,cc3d(iloc:ilen,jloc:jlen,0:kmax,1:numc),start(1:3),edges(1:3))
         if (status .NE. NF90_NOERR) go to 10
#endif
      end if
#endif
   end if
#endif

#ifndef BFM_GOTM
   LEVEL3 'Done reading - closing hotstart file'
   status = nf90_close(ncid)
   if (status .NE. NF90_NOERR) go to 10
#endif
   LEVEL3 'edges: ',edges
   return

10 LEVEL3 'Something bad happened'
   FATAL 'read_restart_ncdf: ',nf90_strerror(status)
   call getm_error('read_restart_ncdf()',nf90_strerror(status))
   stop
   return

   end subroutine read_restart_ncdf
!EOC

!-----------------------------------------------------------------------
! Copyright (C) 2007 - Karsten Bolding (BBH)                           !
!-----------------------------------------------------------------------
