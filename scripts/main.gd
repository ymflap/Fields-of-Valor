extends Node3D
class_name MainController

signal campaign_started
signal mission_started(mission_id: String, mission_index: int)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String)
signal campaign_completed
signal air_support_changed(remaining: int)
signal progress_saved
signal progress_loaded

enum CampaignState {
    NOT_STARTED,
    ACTIVE,
    MISSION_FAILED,
    COMPLETED
}

const SAVE_PATH: String = "user://campaign_progress.cfg"
const SAVE_SECTION: String = "campaign"
const SAVE_VERSION: int = 1
const INITIAL_AIR_SUPPORT: int = 3

var campaign_state: CampaignState = CampaignState.NOT_STARTED
var mission_ids: Array[String] = []
var current_mission_index: int = 0
var remaining_air_support: int = INITIAL_AIR_SUPPORT


func _ready() -> void:
    load_progress()


func start_campaign(new_mission_ids: Array[String]) -> bool:
    var validated_ids: Array[String] = []
    var seen_ids: Dictionary = {}

    for raw_id in new_mission_ids:
        var mission_id: String = raw_id.strip_edges()

        if mission_id.is_empty():
            push_warning("Campaign contains an empty mission ID.")
            return false

        if seen_ids.has(mission_id):
            push_warning("Campaign contains a duplicate mission ID: " + mission_id)
            return false

        seen_ids[mission_id] = true
        validated_ids.append(mission_id)

    if validated_ids.is_empty():
        push_warning("Cannot start a campaign without missions.")
        return false

    mission_ids = validated_ids
    current_mission_index = 0
    remaining_air_support = INITIAL_AIR_SUPPORT
    campaign_state = CampaignState.ACTIVE

    campaign_started.emit()
    mission_started.emit(get_current_mission_id(), current_mission_index)
    save_progress()
    return true


func get_current_mission_id() -> String:
    if current_mission_index < 0 or current_mission_index >= mission_ids.size():
        return ""

    return mission_ids[current_mission_index]


func get_campaign_state() -> CampaignState:
    return campaign_state


func get_current_mission_number() -> int:
    if mission_ids.is_empty():
        return 0

    if campaign_state == CampaignState.COMPLETED:
        return mission_ids.size()

    return current_mission_index + 1


func get_total_missions() -> int:
    return mission_ids.size()


func complete_current_mission() -> bool:
    if campaign_state != CampaignState.ACTIVE:
        return false

    var completed_id: String = get_current_mission_id()
    if completed_id.is_empty():
        return false

    mission_completed.emit(completed_id)
    current_mission_index += 1

    if current_mission_index >= mission_ids.size():
        campaign_state = CampaignState.COMPLETED
        campaign_completed.emit()
    else:
        mission_started.emit(get_current_mission_id(), current_mission_index)

    save_progress()
    return true


func fail_current_mission() -> bool:
    if campaign_state != CampaignState.ACTIVE:
        return false

    var failed_id: String = get_current_mission_id()
    if failed_id.is_empty():
        return false

    campaign_state = CampaignState.MISSION_FAILED
    mission_failed.emit(failed_id)
    save_progress()
    return true


func retry_current_mission() -> bool:
    if campaign_state != CampaignState.MISSION_FAILED:
        return false

    if current_mission_index < 0 or current_mission_index >= mission_ids.size():
        return false

    campaign_state = CampaignState.ACTIVE
    mission_started.emit(get_current_mission_id(), current_mission_index)
    save_progress()
    return true


func use_air_support() -> bool:
    if campaign_state != CampaignState.ACTIVE:
        return false

    if remaining_air_support <= 0:
        return false

    remaining_air_support -= 1
    air_support_changed.emit(remaining_air_support)
    save_progress()
    return true


func save_progress() -> bool:
    var config := ConfigFile.new()

    config.set_value(SAVE_SECTION, "version", SAVE_VERSION)
    config.set_value(SAVE_SECTION, "mission_ids", mission_ids)
    config.set_value(SAVE_SECTION, "current_mission_index", current_mission_index)
    config.set_value(SAVE_SECTION, "campaign_state", int(campaign_state))
    config.set_value(SAVE_SECTION, "remaining_air_support", remaining_air_support)

    var error: Error = config.save(SAVE_PATH)
    if error != OK:
        push_error("Could not save campaign progress. Error code: " + str(error))
        return false

    progress_saved.emit()
    return true


func load_progress() -> bool:
    var config := ConfigFile.new()
    var error: Error = config.load(SAVE_PATH)

    if error != OK:
        if error != ERR_FILE_NOT_FOUND:
            push_warning("Could not load campaign progress. Error code: " + str(error))
        return false

    var version: int = int(config.get_value(SAVE_SECTION, "version", -1))
    if version != SAVE_VERSION:
        push_warning("Saved campaign progress uses an unsupported version.")
        return false

    var saved_ids: Variant = config.get_value(SAVE_SECTION, "mission_ids", [])
    if typeof(saved_ids) != TYPE_ARRAY:
        push_warning("Saved mission list is invalid.")
        return false

    var restored_ids: Array[String] = []
    var seen_ids: Dictionary = {}

    for raw_id in saved_ids:
        if typeof(raw_id) != TYPE_STRING:
            push_warning("Saved mission ID has an invalid type.")
            return false

        var mission_id: String = str(raw_id).strip_edges()
        if mission_id.is_empty() or seen_ids.has(mission_id):
            push_warning("Saved mission list contains an invalid or duplicate ID.")
            return false

        seen_ids[mission_id] = true
        restored_ids.append(mission_id)

    var saved_index: int = int(config.get_value(SAVE_SECTION, "current_mission_index", -1))
    var saved_state_value: int = int(config.get_value(SAVE_SECTION, "campaign_state", -1))
    var saved_support: int = int(config.get_value(SAVE_SECTION, "remaining_air_support", -1))

    if restored_ids.is_empty():
        push_warning("Saved campaign has no missions.")
        return false

    if saved_index < 0 or saved_index > restored_ids.size():
        push_warning("Saved mission index is out of range.")
        return false

    if saved_state_value < int(CampaignState.NOT_STARTED) \
    or saved_state_value > int(CampaignState.COMPLETED):
        push_warning("Saved campaign state is invalid.")
        return false

    if saved_support < 0 or saved_support > INITIAL_AIR_SUPPORT:
        push_warning("Saved air support count is invalid.")
        return false

    var restored_state := CampaignState.values()[saved_state_value] as CampaignState

    if restored_state == CampaignState.ACTIVE \
    or restored_state == CampaignState.MISSION_FAILED:
        if saved_index >= restored_ids.size():
            push_warning("Saved active mission index is invalid.")
            return false

    if restored_state == CampaignState.COMPLETED \
    and saved_index != restored_ids.size():
        push_warning("Saved completed campaign index is invalid.")
        return false

    mission_ids = restored_ids
    current_mission_index = saved_index
    campaign_state = restored_state
    remaining_air_support = saved_support

    progress_loaded.emit()
    air_support_changed.emit(remaining_air_support)
    return true
    
