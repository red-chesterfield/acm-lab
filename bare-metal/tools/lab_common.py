
# Some common functions for ACM Lab Fog-machine stuff.

# Assumes: Python 3.6+

import json
import sys

import os
import yaml

from misc_utils import *
from bmc_common import *


# --- Lab-tailored BMC Classes ---

class LabBMCConnection(object):

   # Notes:
   #
   # - This class contains an instance of a (Dell) BMC Connection object rather than
   #   being a subclasses of it in case we have non-Dell hardware in the future and
   #   we want this class to act as a fascade over all kinds.

   @staticmethod
   def add_bmc_login_argument_definitions(parser):

      parser.add_argument("--username", "-u",  dest="login_username")
      parser.add_argument("--password", "-p",  dest="login_password")
      parser.add_argument("--use-default-creds", "-D",  dest="use_default_creds", action="store_true")
      parser.add_argument("--as-admin", "-A",  dest="as_admin", action="store_true")
      parser.add_argument("--as-root",  "-R",  dest="as_root", action="store_true")
      parser.add_argument("--as-mgmt",  "-M",  dest="as_mgmt", action="store_true")

   @staticmethod
   def create_connection(machine_name, args, default_to_admin=False):

      username = args.login_username
      password = args.login_password
      for_std_user = None
      if args.use_default_creds:
         for_std_user = "default"
      elif args.as_root:
         for_std_user = "root"
      elif args.as_mgmt:
         for_std_user = "mgmt"
      elif args.as_admin or default_to_admin:
         for_std_user = "admin"

      if username is not None:
         dbg("Creating connection to %s as specified user\" %s\"." % (machine_name, username), level=1)
      elif for_std_user is not None:
         dbg("Creating connection to %s as standard user \"%s\"." % (machine_name, for_std_user), level=1)
      else:
         dbg("Creating connection to %s using default standard user." % machine_name, level=1)

      return LabBMCConnection(machine_name, username=username, password=password,
                              for_std_user=for_std_user)

   def __init__(self, machine_name, username=None, password=None, for_std_user=None):

      if (username is not None) != (password is not None):
         die("Both BMC login username and password are required if either is provided.")

      self.machine_info = None
      bmc_cfg = self._get_bmc_cfg(machine_name, for_std_user=for_std_user)

      self.host = bmc_cfg["address"]
      self.username = bmc_cfg["username"] if username is None else username
      self.password = bmc_cfg["password"] if password is None else password
      # Future: Maybe also accept username/password from env vars?

      self.connection = DellBMCConnection(self.host, self.username, self.password)

      # Because we're doing things by composition of rahter than subclassing from the
      # BMCConnection class, we have to explicitly "export" the methods of the
      # BMCConnection classs that we want to be part of our API.

      self.get_resource           = self.connection.get_resource
      self.get_collection         = self.connection.get_collection
      self.get_collection_members = self.connection.get_collection_members
      self.get_collection_member_ids       = self.connection.get_collection_member_ids
      self.get_collection_member_with_name = self.connection.get_collection_member_with_name

      self.get_service_root_resource   = self.connection.get_service_root_resource
      self.get_system_resource         = self.connection.get_this_system_resource
      self.get_system_manager_resource = self.connection.get_this_system_manager_resource

      self.update_resource_by_id       = self.connection.update_resource_by_id

      self.start_task     = self.connection.start_task
      self.get_task       = self.connection.get_task
      self.perform_action = self.connection.perform_action

      self.get_power_state         = self.connection.get_power_state
      self.get_system_power_state  = self.connection.get_power_state
      self.system_power_on         = self.connection.system_power_on
      self.system_power_off        = self.connection.system_power_off

      self.get_all_accounts     = self.connection.get_all_accounts
      self.get_account          = self.connection.get_account
      self.create_account       = self.connection.create_account
      self.delete_account       = self.connection.delete_account
      self.set_account_password = self.connection.set_account_password

   def _get_bmc_cfg(self, machine_name, for_std_user=None):

      m_entry = None
      bmc_cfg = {}
      try:
         m_entry = get_machine_entry(machine_name, for_std_user=for_std_user)
         bmc_info = m_entry["bmc"]
         bmc_cfg["address"]  = bmc_info["address"]
         bmc_cfg["username"] = bmc_info["username"]
         bmc_cfg["password"] = bmc_info["password"]
      except KeyError:
         if m_entry is None:
            die("Machine %s not recored in machine info db." % machine_name)
         else:
            die("Machine info db not as expected (bmc data missing/wrong).")

      return bmc_cfg


# --- Getting info from our lab machine-info database (yaml file) ---

machine_info = None

def _load_machine_info_db(for_std_user=None):

   global machine_info

   if machine_info is not None:
      return

   # Get BMC address and creds from our machine info database (yaml files).

   machine_db_yaml = os.getenv("ACM_LAB_MACHINE_INFO")
   if machine_db_yaml is None:
      machine_db_yaml = os.getenv("FOG_MACHINE_INFO")
   if machine_db_yaml is None:
      die("Environment variable ACM_LAB_MACHINE_INFO is not set.")
   machine_creds_yaml = os.getenv("ACM_LAB_MACHINE_CREDS")
   if machine_creds_yaml is None:
      machine_creds_yaml = os.getenv("FOG_MACHINE_CREDS")
   if machine_creds_yaml is None:
      die("Environment variable ACM_LAB_MACHINE_CREDS is not set.")

   for_std_user = for_std_user if for_std_user is not None else "bmc"
   if for_std_user not in ["bmc", "default", "root", "admin", "mgmt"]:
      die("Requested standard user \"%s\"%s is not recognized." % for_std_user)

   # Load DB and convert it into a dict indexed by machine name.

   try:
      with open(machine_db_yaml, "r") as stream:
         machine_db = yaml.safe_load(stream)
   except FileNotFoundError:
      die("Machine info db file not found: %s" % machine_db_yaml)

   try:
      machine_info = {e["name"]: e for e in machine_db["machines"]}
   except KeyError:
      die("Machine info db not as expected (no machines list).")

   # Load creds into and merge into the machine db entries.

   try:
      with open(machine_creds_yaml, "r") as stream:
         creds_info = yaml.safe_load(stream)
   except FileNotFoundError:
      die("Machine creds db file not found: %s" % machine_creds_yaml)

   global_creds_entry = "bmc" if for_std_user == "bmc" else "bmc-%s" % for_std_user
   global_creds = None
   try:
      global_creds = creds_info["global"][global_creds_entry]
      global_username = global_creds["username"]
      global_password = global_creds["password"]
   except KeyError:
      die("Machine creds db does not have global creds for standard user \"%s\"." % for_std_user)
   # In Future, maybe we'll add per-machine cred overrides but none such for now.

   # Merge the creds into each machine_info entry if none already there.

   try:
      for m_entry in machine_info.values():
         bmc_info = m_entry["bmc"]
         if "username" not in bmc_info:
            bmc_info["username"] = global_username
         if "password" not in bmc_info:
            bmc_info["password"] = global_password

   except KeyError:
      die("Machine info db not as expected (bmc data missing/wrong).")

def get_machine_entry(machine_name, for_std_user=None):

   _load_machine_info_db(for_std_user=for_std_user)


   # Although the machine name key in the database isn't a hostname, we often
   # use it as the first component of a dotted fully-squalified hostname.
   # As a conveninece, accept it that form and use the first component as
   # the machine name.

   machine_name,junk = split_at(machine_name, ".", favor_right=False)

   try:
      return machine_info[machine_name]
   except KeyError:
      die("Machine %s not recored in machine info db." % machine_name)
   #
#


# -- Iterating across a bunch of machines to do the same thing ---

# Task orchestrator that runs running a given task/job across a set of machines.
# Task particulars are specified via a passed task-customization class.

class TaskRunner:

   def __init__(self, machines, connection_args, the_task_class,
                task_arg=None, default_to_admin=False):

      self.machines         = machines
      self.connection_args  = connection_args
      self.the_task_class   = the_task_class
      self.task_arg         = task_arg
      self.default_to_admin = default_to_admin

      self.tasks = dict()

   def run(self):

      # Open BMC connections to each of the machines and do quick pre-checks.
      # If pre-checks fail for any machine, we abort the whole thing.

      errors_occurred = False
      for machine in self.machines:

         blurt("Opening BMC connectino with %s and doing verification." % machine)

         bmc_conn = LabBMCConnection.create_connection(machine, self.connection_args,
                                                       default_to_admin=self.default_to_admin)
         this_task = self.the_task_class(machine, bmc_conn, self.task_arg)

         if this_task.pre_check():
            self.tasks[machine] = this_task
         else:
            errors_occurred = True
      #
      if errors_occurred:
         blurt("Aborting because one or more machines failed verification checks.")
         return

      # Give the tasks a chance to prepare input, or decline to do so, before
      # we start any real work.

      tasks_are_needed = False

      for machine in list(self.tasks.keys()):
         task = self.tasks[machine]
         if task.prepare_task_request():
            tasks_are_needed = True
         else:
            blurt("[%s] No task is necessary for this machine." % machine)
            del self.tasks[machine]
      #
      if not tasks_are_needed:
         blurt("No tasks are needed.")
         return

      # Perform pre-submit pass, intnedned to get every machine into whatever
      # pre-task-submit state is required if more than power control is needed.

      self.the_task_class.announce_pre_submit_pass()
      pause_after_pass = False
      for machine in list(self.tasks.keys()):
         task = self.tasks[machine]
         try:
            pause_after_pass = task.pre_submit() or pause_after_pass
         except BMCError as exc:
            emsg(str(exc))
            blurt("Abandoning futher action for %s due to preceeding errors." % machine)
            del self.tasks[machine]
      #
      if not self.tasks:
         blurt("No machines successfully estbalished pre-submit conditions.")
         return

      if pause_after_pass:
         blurt("Pausing a bit to allow the iDRACs to catch up.")
         time.sleep(15)  # Really gross.

      # Submit the task requests

      short_task_name = self.the_task_class.get_short_task_name()
      blurt("Submitting %s task requests." % short_task_name)

      for machine in list(self.tasks.keys()):
         task = self.tasks[machine]
         bmc_conn = task.get_bmc_conn()

         try:
            task_target = task.get_task_target()
            task_body   = task.get_task_body()

            if task_target is None:
               reason = "No task target set"
               blurt("[%s] Abaonding further action for machine: %s." % (machine, reason))
               del self.tasks[machine]
            else:
               blurt("   Submitting task on %s." % machine)
               task_id = bmc_conn.start_task(task_target, task_body)
               dbg("Task id: %s" % task_id)
               task.set_task_id(task_id)
         except BMCRequestError as exc:
            emsg("[%s] Request error: %s" % (machine, exc))
            reason = "Could not submit %s task" % short_task_name
            blurt("[%s] Abaonding further action for machine: %s." % (machine, reason))
            del self.tasks[machine]
      #

      if not self.tasks:
         blurt("No %s tasks were successfully started." % short_task_name)
         return

      blurt("Pausing a bit to allow the iDRACs to catch up.")
      time.sleep(15)  # Really gross.

      # Perform post-submit pass, intnedned to niudge every machine in whatever
      # way needed to get them to run the pending tasks, for example powering them on.

      self.the_task_class.announce_post_submit_pass()
      pause_after_pass = False
      for machine in list(self.tasks.keys()):
         task = self.tasks[machine]
         try:
            pause_after_pass = task.post_submit() or pause_after_pass
         except BMCError as exc:
            emsg("[%s] %s" % (machine, str(exc)))
            blurt("[%s] Abandoning futher action for machine due to preceeding errors." % machine)
            del self.tasks[machine]
      #
      if not self.tasks:
         blurt("No machines successfully estbalished pre-submit conditions.")
         return

      if pause_after_pass:
         blurt("Pausing a bit to allow the iDRACs to catch up.")
         time.sleep(15)  # Really gross.

      # Wait until the tasks complete or fail on all of the machines.

      print("Waiting for submmitted %s tasks to complete." % short_task_name)
      pending_tasks = {m:t for m, t in self.tasks.items()}

      while pending_tasks:
         for machine in list(pending_tasks.keys()):
            task = pending_tasks[machine]
            bmc_conn = task.get_bmc_conn()
            task_id  = task.get_task_id()

            try:
               task_res = bmc_conn.get_task(task_id)
               if task_has_ended(task_res):
                  blurt("[%s] Task for machine has ended." % task.machine)
                  del pending_tasks[machine]
                  task.ending_task_res = task_res ## Should use a setter ##
               else:
                  task_state = task_res["TaskState"]
                  if task_state == "Starting":
                     # On Dell iDRAC, it seems tasks remaining in Starting while the system is
                     # going through its power-on initialization.  Then the task transitions
                     # to running when LC has control.
                     blurt("[%s] Machine is still starting up." % machine)
                  else:
                     tasK_pct_complete = task_res["PercentComplete"]
                     blurt("[%s] Task still in progress: %s (%d%% complete)." %
                           (machine, task_state, tasK_pct_complete))

            except BMCRequestError as exc:
               emsg("[%s] BMC request error: %s" % (machine, exc))
               del pending_tasks[machine]
               task.ending_task_res = None
               blurt("[%s] Abaonding further action for machine: %s." % (machine, reason))
               del self.tasks[machine]
         #
         if len(pending_tasks) > 0:
            time.sleep(15)
      #

      # All tasks have ended.  Report on completion.

      for machine in list(self.tasks.keys()):
         task = self.tasks[machine]
         task_res = task.ending_task_res

         if task_res is not None:
            task_status = task_res["TaskStatus"]
            task_state = task_res["TaskState"]
            if task_status == "OK":
               blurt("[%s] Task %s has comopleted successfully." % (machine, short_task_name))
            else:
               blurt("[%s] Task %s has failed.  Ending tatus/state: %s/%s" %
                     (machine, short_task_name, task_status, task_state))
         else:
            blurt("[%s] Task %s state is unknown due to previous errors." % (machine, short_task_name))
      #

      # Perform post-completion pass, intnedned to get every machine into whatever post-
      # completion state is desired, such as powering off again if the task needed to
      # leave the machine powered on.

      self.the_task_class.announce_post_completion_pass()
      for machine in list(self.tasks.keys()):
         task = self.tasks[machine]
         task.post_completion()
      #

      blurt("Finished.")


class RunnableTask:

   def __init__(self, machine, bmc_conn, task_arg=None):

      self.machine  = machine
      self.bmc_conn = bmc_conn

      self.task_target = None
      self.task_body   = None

   def get_bmc_conn(self):
      return self.bmc_conn

   def set_task_id(self, task_id):
      self.task_id = task_id

   def get_task_id(self):
      return self.task_id

   def pre_check(self):
      return True

   def prepare_task_request(self):
      # Give task a chance to defer prep of task target or body until we need it.
      return True

   def get_task_target(self):
      return self.task_target

   def get_task_body(self):
      return None

   @classmethod
   def announce_pre_submit_pass(self):
      return

   def pre_submit(self):
      return False  # Didn't do anything, so no BMC-catch-up pausing needed.

   @classmethod
   def announce_post_submit_pass(self):
      return

   def post_submit(self):
      return False  # Didn't do anothing, so no BMC-catch-up pausing needed.

   @classmethod
   def announce_post_completion_pass(self):
      return

   def post_completion(self):
      return

   def do_power_action(self, desired_power_state):

      machine = self.machine
      bmc_conn = self.bmc_conn

      did_something = False
      try:
         current_power_state = bmc_conn.get_power_state()
         dbg("Server %s power state: %s" % (machine, current_power_state))
         if current_power_state != desired_power_state:
            print("   Powering %s %s." % (machine, desired_power_state))
            if desired_power_state == "Off":
               bmc_conn.system_power_off()
            else:
               bmc_conn.system_power_on()
            did_something = True
         else:
            print("   System %s was already Powered %s." % (machine, desired_power_state))

      except BMCRequestError as exc:
         m = "Could not check/control power for machine  %s: %s" % (machine, exc)
         raise BMCError(m)

class DellSpecificTask(RunnableTask):

   def __init__(self, machine, bmc_conn, task_arg=None):
      super(DellSpecificTask, self).__init__(machine, bmc_conn, task_arg)

   def verify_vendor_is_dell(self):

      # Make sure we're managing a Dell server because our actions make
      # use of Dell-specific resources/actions.

      service_root_res = self.bmc_conn.get_service_root_resource()
      vendor = service_root_res["Vendor"]
      if vendor != "Dell":
         emsg("Machine %s is not a Dell server." % self.machine)
         return False
      return True

   def pre_check(self):
     return self.verify_vendor_is_dell()
#
