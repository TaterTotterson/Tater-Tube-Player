#include "GamepadInput.h"

#ifdef TATER_PLAYER_HAS_SDL2
#include <SDL2/SDL.h>
#endif

namespace {
constexpr int kStickDeadZone = 16000;
constexpr qint64 kInitialRepeatDelayMs = 340;
constexpr qint64 kRepeatDelayMs = 115;
}

GamepadInput::GamepadInput(QObject *parent)
    : QObject(parent)
{
    m_elapsed.start();

#ifdef TATER_PLAYER_HAS_SDL2
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_EVENTS) == 0) {
        openFirstController();
        m_pollTimer.setInterval(8);
        connect(&m_pollTimer, &QTimer::timeout, this, &GamepadInput::poll);
        m_pollTimer.start();
    }
#endif
}

GamepadInput::~GamepadInput()
{
#ifdef TATER_PLAYER_HAS_SDL2
    closeController();
    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_EVENTS);
#endif
}

void GamepadInput::setConnected(bool connected)
{
    if (m_connected == connected)
        return;
    m_connected = connected;
    emit connectedChanged();
}

void GamepadInput::openFirstController()
{
#ifdef TATER_PLAYER_HAS_SDL2
    if (m_controller)
        return;

    for (int index = 0; index < SDL_NumJoysticks(); ++index) {
        if (!SDL_IsGameController(index))
            continue;
        auto *controller = SDL_GameControllerOpen(index);
        if (!controller)
            continue;
        m_controller = controller;
        setConnected(true);
        return;
    }
#endif
}

void GamepadInput::closeController()
{
#ifdef TATER_PLAYER_HAS_SDL2
    if (m_controller) {
        SDL_GameControllerClose(static_cast<SDL_GameController *>(m_controller));
        m_controller = nullptr;
    }
#endif
    setConnected(false);
    m_axisDirections[0] = 0;
    m_axisDirections[1] = 0;
}

void GamepadInput::emitAxisDirection(int axisIndex, int direction)
{
    if (axisIndex == 0) {
        if (direction < 0)
            emit navigateLeft();
        else if (direction > 0)
            emit navigateRight();
    } else {
        if (direction < 0)
            emit navigateUp();
        else if (direction > 0)
            emit navigateDown();
    }
}

void GamepadInput::updateAxis(int axisIndex, int direction)
{
    const qint64 now = m_elapsed.elapsed();
    if (m_axisDirections[axisIndex] != direction) {
        m_axisDirections[axisIndex] = direction;
        m_axisRepeatAt[axisIndex] = now + kInitialRepeatDelayMs;
        if (direction != 0)
            emitAxisDirection(axisIndex, direction);
        return;
    }

    if (direction != 0 && now >= m_axisRepeatAt[axisIndex]) {
        m_axisRepeatAt[axisIndex] = now + kRepeatDelayMs;
        emitAxisDirection(axisIndex, direction);
    }
}

void GamepadInput::poll()
{
#ifdef TATER_PLAYER_HAS_SDL2
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_CONTROLLERDEVICEADDED) {
            openFirstController();
        } else if (event.type == SDL_CONTROLLERDEVICEREMOVED && m_controller) {
            auto *controller = static_cast<SDL_GameController *>(m_controller);
            auto *joystick = SDL_GameControllerGetJoystick(controller);
            if (SDL_JoystickInstanceID(joystick) == event.cdevice.which) {
                closeController();
                openFirstController();
            }
        } else if (event.type == SDL_CONTROLLERBUTTONDOWN) {
            switch (event.cbutton.button) {
            case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
                emit navigateLeft();
                break;
            case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
                emit navigateRight();
                break;
            case SDL_CONTROLLER_BUTTON_DPAD_UP:
                emit navigateUp();
                break;
            case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
                emit navigateDown();
                break;
            case SDL_CONTROLLER_BUTTON_A:
                emit accept();
                break;
            case SDL_CONTROLLER_BUTTON_B:
                emit back();
                break;
            default:
                break;
            }
        }
    }

    if (!m_controller) {
        openFirstController();
        return;
    }

    auto *controller = static_cast<SDL_GameController *>(m_controller);
    if (!SDL_GameControllerGetAttached(controller)) {
        closeController();
        openFirstController();
        return;
    }

    const auto horizontal = SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_LEFTX);
    const auto vertical = SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_LEFTY);
    updateAxis(0, horizontal < -kStickDeadZone ? -1 : (horizontal > kStickDeadZone ? 1 : 0));
    updateAxis(1, vertical < -kStickDeadZone ? -1 : (vertical > kStickDeadZone ? 1 : 0));
#endif
}
